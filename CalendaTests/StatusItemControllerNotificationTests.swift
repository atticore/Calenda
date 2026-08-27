//
//  StatusItemControllerNotificationTests.swift
//  CalendaTests
//
//  Created by atticore on 2026/8/27.
//

import AppKit
import Testing
@testable import Calenda

/// 系统跨天/时区/唤醒通知由系统在非主线程投递（与
/// __postAndResetMidnight 的行为一致）；StatusItemController 必须把
/// 刷新安全收敛到主线程执行。回归：午夜 .NSCalendarDayChanged
/// 后台投递触发 Swift 运行时 executor 检查 SIGTRAP，进程退出。
@MainActor
struct StatusItemControllerNotificationTests {
    private enum Fixture {
        static let pollIntervalMilliseconds = 50
        static let timeoutSeconds: TimeInterval = 3
    }

    /// 记录每次 `now` 读取时是否在主线程。`@unchecked Sendable`
    /// 的不变量：samples 仅经 lock 访问，Date 值本身不可变。
    private final class ThreadRecordingClock: ClockProviding, @unchecked Sendable {
        private let lock = NSLock()
        private var samples: [Bool] = []

        var now: Date {
            let isMainThread = Thread.isMainThread
            lock.withLock { samples.append(isMainThread) }
            return Date()
        }

        var mainThreadSamples: [Bool] {
            lock.withLock { samples }
        }
    }

    @MainActor
    private final class NoopPanelController: PanelControlling {
        func togglePanel(relativeTo statusButton: NSStatusBarButton) {}
        func closePanel(reason: PanelCloseReason) {}
    }

    /// controller 仅弱引用 panel；两者由测试作用域共同持有存活。
    private func makeController(
        clock: ThreadRecordingClock
    ) -> (controller: StatusItemController, panel: NoopPanelController) {
        let panel = NoopPanelController()
        let controller = StatusItemController(panelController: panel, clock: clock)
        return (controller, panel)
    }

    private func postOffMain(_ name: Notification.Name) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                NotificationCenter.default.post(name: name, object: nil)
                continuation.resume()
            }
        }
    }

    private func postWorkspaceOffMain(_ name: Notification.Name) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                NSWorkspace.shared.notificationCenter.post(name: name, object: nil)
                continuation.resume()
            }
        }
    }

    /// 轮询等待刷新发生，返回基线之后新增的主线程样本。
    private func waitForRefresh(
        after baseline: Int,
        sampling clock: ThreadRecordingClock
    ) async -> [Bool] {
        let deadline = Date().addingTimeInterval(Fixture.timeoutSeconds)
        while clock.mainThreadSamples.count <= baseline, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(Fixture.pollIntervalMilliseconds))
        }
        return Array(clock.mainThreadSamples.dropFirst(baseline))
    }

    @Test
    func refreshesOnMainActorWhenDayChangeArrivesOffMain() async {
        let clock = ThreadRecordingClock()
        let harness = makeController(clock: clock)
        let baseline = clock.mainThreadSamples.count

        await postOffMain(.NSCalendarDayChanged)

        let samples = await waitForRefresh(after: baseline, sampling: clock)
        #expect(
            !samples.isEmpty,
            "后台投递 .NSCalendarDayChanged 后应触发一次刷新"
        )
        #expect(
            samples.allSatisfy { $0 },
            "通知触发的刷新必须全部在主线程执行"
        )
    }

    @Test
    func refreshesOnMainActorWhenWorkspaceWakeArrivesOffMain() async {
        let clock = ThreadRecordingClock()
        let harness = makeController(clock: clock)
        let baseline = clock.mainThreadSamples.count

        await postWorkspaceOffMain(NSWorkspace.didWakeNotification)

        let samples = await waitForRefresh(after: baseline, sampling: clock)
        #expect(
            !samples.isEmpty,
            "后台投递 didWakeNotification 后应触发一次刷新"
        )
        #expect(
            samples.allSatisfy { $0 },
            "通知触发的刷新必须全部在主线程执行"
        )
    }

    /// 设置变更走独立动作（refresh 不重建 formatter）；
    /// 该观察者迁移到 block 方式后，设置变化仍必须驱动菜单栏刷新。
    @Test
    func refreshesMenuBarStyleWhenSettingsChangeArrivesOffMain() async {
        let clock = ThreadRecordingClock()
        let harness = makeController(clock: clock)
        let baseline = clock.mainThreadSamples.count

        await postOffMain(.appSettingsDidChange)

        let samples = await waitForRefresh(after: baseline, sampling: clock)
        #expect(
            !samples.isEmpty,
            "设置变更通知应触发一次菜单栏样式刷新"
        )
        #expect(
            samples.allSatisfy { $0 },
            "设置触发的刷新必须全部在主线程执行"
        )
    }
}
