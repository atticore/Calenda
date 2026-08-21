//
//  CalendaUITests.swift
//  CalendaUITests
//
//  Created by atticore on 2026/8/19.
//

import AppKit
import CoreGraphics
import XCTest

final class CalendaUITests: XCTestCase {
    private enum Fixture {
        static let accessibilityLabel = "Calenda 日历"
        static let existenceTimeout: TimeInterval = 5
        static let hittablePollTimeout: TimeInterval = 1.5
        static let pollInterval: TimeInterval = 0.2
        /// 状态项下方约 12 个按钮高度处是面板中部（正 y 区域）。
        static let panelActivationOffset = CGVector(dx: 0.5, dy: 12)
    }

    override class func setUp() {
        // 首个键盘事件合成前切走第三方输入法，避免 testmanagerd 授权弹窗。
        InputSourceGuard.engage()
    }

    override class func tearDown() {
        InputSourceGuard.restore()
    }

    override func setUp() {
        // 状态项按 accessibility label 跨进程匹配：单元测试宿主或手工
        // 启动的残留实例会让点击落到别的进程，面板在错误实例中打开。
        // 测试启动前清理同名实例，保证本用例面对唯一的菜单栏项。
        let cleanup = Process()
        cleanup.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        cleanup.arguments = ["-x", "Calenda"]
        try? cleanup.run()
        cleanup.waitUntilExit()
    }

    @MainActor
    func testStatusItemOpensAndClosesPanel() throws {
        continueAfterFailure = false
        guard !isSessionLocked else {
            // 锁屏/登录窗口会吞掉所有合成事件，状态项也永远不可命中；
            // 此环境无法做真实交互断言，跳过而不是误报失败。
            throw XCTSkip("User session is locked; panel interaction needs an unlocked session")
        }
        let application = XCUIApplication()
        // 测试环境禁用节假日网络刷新，保持用例离线确定性（设计 18.2）
        application.launchEnvironment["CALENDA_DISABLE_NETWORK_REFRESH"] = "1"
        application.launch()
        application.activate()

        var openedByRealClick = false
        openPanel(application: application, openedByRealClick: &openedByRealClick)

        // 面板断言走窗口服务器而非 AX：副屏位于主屏上方时 AX 快照
        // 看不到该窗口，但 CGWindowList 在任意显示器/空间上都可见。
        XCTAssertTrue(
            waitForPanel(visible: true, timeout: Fixture.existenceTimeout),
            "Calendar panel did not appear"
        )

        // Escape 由应用内的本地按键监视器处理，前提是应用被点击激活：
        // 注入路径没有真实点击，用面板中部（正 y 区域）的一次点击补齐
        // 激活，这与用户点开面板后的焦点状态一致。
        if !openedByRealClick {
            activatePanel(application: application)
        }
        application.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(
            waitForPanel(visible: false, timeout: Fixture.existenceTimeout),
            "Calendar panel did not close after Escape"
        )
    }

    /// 优先真实点击状态项；无可命中实例（副屏在主屏上方、
    /// 菜单栏拥挤溢出等环境）时重启并注入开面板环境变量，
    /// 应用内走与左键完全相同的路径（设计 18.2）。
    @MainActor
    private func openPanel(
        application: XCUIApplication,
        openedByRealClick: inout Bool
    ) {
        let items = application.statusItems.matching(
            NSPredicate(format: "label == %@", Fixture.accessibilityLabel)
        )
        XCTAssertTrue(
            items.firstMatch.waitForExistence(timeout: Fixture.existenceTimeout),
            "Calenda status item did not appear"
        )

        let deadline = Date().addingTimeInterval(Fixture.hittablePollTimeout)
        var statusItem = items.allElementsBoundByIndex.first { $0.isHittable }
        while statusItem == nil && Date() < deadline {
            Thread.sleep(forTimeInterval: Fixture.pollInterval)
            statusItem = items.allElementsBoundByIndex.first { $0.isHittable }
        }

        if let statusItem {
            statusItem.click()
            openedByRealClick = true
        } else {
            application.terminate()
            application.launchEnvironment["CALENDA_UI_TEST_OPEN_PANEL"] = "1"
            application.launch()
        }
    }

    /// 点击面板中部使应用激活、面板成为 key 窗口：
    /// 以状态项为锚（其 AX 元素始终可见）做大幅向下偏移，
    /// 命中面板内部的正 y 区域；副屏在主屏上方时负 y 的事件
    /// 合成会丢失，因此不能直接点状态项。
    @MainActor
    private func activatePanel(application: XCUIApplication) {
        let items = application.statusItems.matching(
            NSPredicate(format: "label == %@", Fixture.accessibilityLabel)
        )
        XCTAssertTrue(
            items.firstMatch.waitForExistence(timeout: Fixture.existenceTimeout),
            "Calenda status item did not reappear after relaunch"
        )
        items.firstMatch.coordinate(
            withNormalizedOffset: Fixture.panelActivationOffset
        ).click()
    }

    /// 锁屏时前台进程是 loginwindow（无 bundleIdentifier）。
    private var isSessionLocked: Bool {
        NSWorkspace.shared.frontmostApplication?.localizedName == "loginwindow"
    }

    /// Calenda 的非零 layer 窗口只有浮动日历面板；状态项窗口
    /// 属于 SystemUIServer，不会计入本查询。
    private func panelWindowExists() -> Bool {
        guard
            let list = CGWindowListCopyWindowInfo(
                [.optionAll],
                kCGNullWindowID
            ) as? [[String: Any]]
        else {
            return false
        }
        return list.contains { info in
            guard (info["kCGWindowOwnerName"] as? String) == "Calenda",
                  let layer = info["kCGWindowLayer"] as? Int,
                  layer > 0
            else {
                return false
            }
            return true
        }
    }

    private func waitForPanel(
        visible expected: Bool,
        timeout: TimeInterval
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if panelWindowExists() == expected {
                return true
            }
            Thread.sleep(forTimeInterval: Fixture.pollInterval)
        }
        return panelWindowExists() == expected
    }
}
