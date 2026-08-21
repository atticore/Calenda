//
//  CalendaUITests.swift
//  CalendaUITests
//
//  Created by atticore on 2026/8/19.
//

import XCTest

final class CalendaUITests: XCTestCase {
    private enum Fixture {
        static let accessibilityLabel = "Calenda 日历"
        static let existenceTimeout: TimeInterval = 5
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
    func testStatusItemOpensAndClosesPanel() {
        continueAfterFailure = false
        let application = XCUIApplication()
        // 测试环境禁用节假日网络刷新，保持用例离线确定性（设计 18.2）
        application.launchEnvironment["CALENDA_DISABLE_NETWORK_REFRESH"] = "1"
        application.launch()

        let statusItem = application.statusItems[Fixture.accessibilityLabel]
        XCTAssertTrue(
            statusItem.waitForExistence(timeout: Fixture.existenceTimeout),
            "Calenda status item did not appear"
        )

        statusItem.click()
        let panel = application.windows[Fixture.accessibilityLabel]
        XCTAssertTrue(
            panel.waitForExistence(timeout: Fixture.existenceTimeout),
            "Calendar panel did not appear"
        )

        application.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(
            panel.waitForNonExistence(timeout: Fixture.existenceTimeout),
            "Calendar panel did not close after Escape"
        )
    }
}
