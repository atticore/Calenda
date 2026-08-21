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
        // 测试启动前清理同名实例并等待其真正退出——pkill 只表示
        // 信号已发出；旧实例尚在退出途中时，新实例状态项的合成
        // 点击可能被窗口服务器路由到垂死进程。
        let cleanup = Process()
        cleanup.executableURL = URL(fileURLWithPath: "/bin/sh")
        cleanup.arguments = [
            "-c",
            "/usr/bin/pkill -x Calenda 2>/dev/null; "
                + "for i in 1 2 3 4 5 6 7 8 9 10; do "
                + "/usr/bin/pgrep -x Calenda >/dev/null || exit 0; "
                + "/bin/sleep 0.3; done; "
                + "/usr/bin/pkill -9 -x Calenda 2>/dev/null; "
                + "for i in 1 2 3 4 5 6 7 8 9 10; do "
                + "/usr/bin/pgrep -x Calenda >/dev/null || exit 0; "
                + "/bin/sleep 0.3; done; exit 0",
        ]
        try? cleanup.run()
        cleanup.waitUntilExit()
    }

    /// 主交互闭环：点击状态项打开面板，再次点击关闭（设计 5.3 toggle）。
    @MainActor
    func testStatusItemTogglesPanel() throws {
        try throwIfSessionLocked()

        let application = XCUIApplication()
        application.launchEnvironment["CALENDA_DISABLE_NETWORK_REFRESH"] = "1"
        application.launch()
        application.activate()

        try openPanelByRealClick(application)

        XCTAssertTrue(
            waitForPanel(visible: true, timeout: Fixture.existenceTimeout),
            "Calendar panel did not appear"
        )

        // 再次点击可命中的状态项实例：toggle 关闭。开面板触发
        // 焦点/Space 切换后合成点击可能被丢弃，循环重试至面板消失。
        let items = application.statusItems.matching(
            NSPredicate(format: "label == %@", Fixture.accessibilityLabel)
        )
        let closeDeadline = Date().addingTimeInterval(
            Fixture.existenceTimeout * 2
        )
        while panelWindowExists() && Date() < closeDeadline {
            guard
                let item = items.allElementsBoundByIndex.first(where: {
                    $0.isHittable
                })
            else {
                Thread.sleep(forTimeInterval: Fixture.pollInterval)
                continue
            }
            item.click()
            let attemptDeadline = Date().addingTimeInterval(1.5)
            while panelWindowExists() && Date() < attemptDeadline {
                Thread.sleep(forTimeInterval: Fixture.pollInterval)
            }
        }
        XCTAssertTrue(
            waitForPanel(visible: false, timeout: Fixture.pollInterval),
            "Calendar panel did not close after second click"
        )
    }

    /// 键盘关闭路径：Escape 经应用内本地监视器关闭面板（设计 5.3）。
    /// 依赖合成键盘事件可送达：锁屏、Secure Input 持有、面板位于
    /// AX 不可见 Space（副屏独立空间）时按环境限制跳过。
    @MainActor
    func testEscapeClosesPanel() throws {
        try throwIfSessionLocked()
        try throwIfSecureInputHeld()

        let application = XCUIApplication()
        application.launchEnvironment["CALENDA_DISABLE_NETWORK_REFRESH"] = "1"
        application.launch()
        application.activate()

        try openPanelByRealClick(application)

        XCTAssertTrue(
            waitForPanel(visible: true, timeout: Fixture.existenceTimeout),
            "Calendar panel did not appear"
        )

        if !panelVisibleToAccessibility(application) {
            application.terminate()
            throw XCTSkip(
                "Panel window is not visible to accessibility (off-main space); "
                    + "synthesized keys cannot be delivered"
            )
        }

        application.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(
            waitForPanel(visible: false, timeout: Fixture.existenceTimeout),
            "Calendar panel did not close after Escape"
        )
    }

    // MARK: - 共用打开路径

    /// 点击可命中的状态项实例打开面板；无可命中实例（副屏在主屏
    /// 上方、菜单栏拥挤溢出等环境）时跳过——toggle 与键盘用例都
    /// 必须以真实点击驱动，注入路径无法复现同一交互前置条件。
    @MainActor
    private func openPanelByRealClick(
        _ application: XCUIApplication
    ) throws {
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
            return
        }

        application.terminate()
        // toggle 用例必须以真实点击关闭，注入路径无法回合同一交互。
        throw XCTSkip(
            "Status item is not hittable (secondary display above primary "
                + "or menu bar overflow); real-click toggle cannot run"
        )
    }

    /// 面板是否对 AX 可见（决定 typeKey 能否送达）。
    @MainActor
    private func panelVisibleToAccessibility(
        _ application: XCUIApplication
    ) -> Bool {
        application.windows.matching(
            NSPredicate(format: "title == %@", Fixture.accessibilityLabel)
        ).firstMatch.exists
    }

    // MARK: - 环境守卫

    /// 锁屏/登录窗口会吞掉所有合成事件，状态项也永远不可命中。
    @MainActor
    private func throwIfSessionLocked() throws {
        guard isSessionLocked else {
            return
        }
        throw XCTSkip(
            "User session is locked; panel interaction needs an unlocked session"
        )
    }

    private var isSessionLocked: Bool {
        NSWorkspace.shared.frontmostApplication?.localizedName == "loginwindow"
    }

    /// Secure Input（如输入法切换工具常驻持有）会在会话范围内丢弃
    /// 一切合成键盘事件：Escape 无法送达任何应用。
    /// 注意 ioreg 全量输出达数 MB：必须先读完管道（边读边排空）
    /// 再等退出，否则 64KB 管道缓冲写满后进程永不退出。
    private func throwIfSecureInputHeld() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "/usr/sbin/ioreg -w 0 -l | /usr/bin/grep -o 'kCGSSessionSecureInputPID\"=[0-9]*' | /usr/bin/head -1",
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        guard
            let range = output.range(of: "kCGSSessionSecureInputPID\"=")
        else {
            return
        }
        let digits = output[range.upperBound...].prefix { $0.isNumber }
        if let pid = Int(digits), pid > 0 {
            throw XCTSkip(
                "Secure Input held by pid \(pid) blocks synthesized keyboard events"
            )
        }
    }

    // MARK: - 面板存在性（窗口服务器层）

    /// Calenda 在屏的浮动层级窗口只有日历面板；状态项与菜单栏
    /// 窗口层级不同，已 orderOut 的面板不会计入在屏查询。
    private func panelWindowExists() -> Bool {
        guard
            let list = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly],
                kCGNullWindowID
            ) as? [[String: Any]]
        else {
            return false
        }
        // NSWindow.Level.floating 对应的 CG 层级为 3（NSFloatingWindowLevel）。
        let floatingLevel = 3
        return list.contains { info in
            guard (info["kCGWindowOwnerName"] as? String) == "Calenda",
                  (info["kCGWindowLayer"] as? Int) == floatingLevel
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
