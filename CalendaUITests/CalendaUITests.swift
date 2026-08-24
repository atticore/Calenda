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

        // 面板内控件的 accessibility 标签（与 AppText 默认值一致）
        static let monthPickerAccessibilityLabel = "选择年月"
        static let previousYearLabel = "上一年"
        static let octoberLabel = "十月"
        static let nationalDayLabel = "国庆节"
        static let midAutumnLabel = "中秋节"
        static let coldDewSolarTermLabel = "寒露"
        static let combinedHolidayLabel = "国庆节、中秋节"
        static let nationalDayOffDetail = "国庆节 · 休"
        static let midAutumnOffDetail = "中秋节 · 休"
        static let chooseCityLabel = "选择城市"
        static let citySearchPlaceholder = "输入城市名搜索（至少 2 个字符）"
        static let useCurrentLocationLabel = "使用当前位置"
        static let weatherOfflineText = "网络不可用，天气暂不可用"
        static let openSettingsLabel = "设置"
        static let settingsWindowTitle = "设置"
        static let todayTitleIdentifier = "calendar.detail.today-title"
        static let monthSwitchScreenshotName =
            "Stable month switch focus presentation"
        static let screenNumberOffset = 1
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

    /// 连续假期的逐日命名（问题 2 回归）：2025 年国庆中秋合并块里，
    /// 日格徽标只在锚点日显示具体节日名（10/1 国庆节、10/6 中秋节），
    /// 中间日不显示公告合并名，节气（10/8 寒露）不被压掉；详情行
    /// 锚点日与所属的连续假期日显示相同的具体节日名。
    @MainActor
    func testCombinedHolidayNamesOnlyAnchorsInDayCells() throws {
        try throwIfSessionLocked()

        let application = XCUIApplication()
        application.launchEnvironment["CALENDA_DISABLE_NETWORK_REFRESH"] = "1"
        // 此用例验证面板内容而非状态项点击。使用会话级默认城市并
        // 直接打开面板，隔离用户保存的位置偏好和重复状态项实例。
        application.launchEnvironment["CALENDA_UI_TEST_USE_DEFAULT_CITY"] = "1"
        application.launchEnvironment["CALENDA_UI_TEST_OPEN_PANEL"] = "1"
        application.launch()
        application.activate()

        XCTAssertTrue(
            waitForPanel(visible: true, timeout: Fixture.existenceTimeout),
            "Calendar panel did not appear"
        )

        // 月选择器导航到 2025 年 10 月（内置快照，离线可用）
        let monthPickerButton = application.buttons[
            Fixture.monthPickerAccessibilityLabel
        ]
        XCTAssertTrue(
            monthPickerButton.waitForExistence(timeout: Fixture.existenceTimeout),
            "Month picker button is not exposed to accessibility"
        )
        let todayButton = application.buttons["今天"]
        XCTAssertTrue(
            todayButton.waitForExistence(timeout: Fixture.existenceTimeout),
            "Today navigation button is not exposed"
        )
        let initialTodayButtonMinX = todayButton.frame.minX
        monthPickerButton.click()

        let previousYearButton = application.buttons[Fixture.previousYearLabel]
        XCTAssertTrue(
            previousYearButton.waitForExistence(timeout: Fixture.existenceTimeout),
            "Month picker did not present year navigation"
        )
        previousYearButton.click()

        let octoberButton = application.buttons[Fixture.octoberLabel]
        XCTAssertTrue(
            octoberButton.waitForExistence(timeout: Fixture.existenceTimeout),
            "Month picker did not present October"
        )
        octoberButton.click()
        XCTAssertEqual(
            todayButton.frame.minX,
            initialTodayButtonMinX,
            accuracy: 0.5,
            "Changing the month title must not move the trailing toolbar"
        )

        let todayTitle = application.staticTexts[Fixture.todayTitleIdentifier]
        XCTAssertTrue(
            todayTitle.waitForExistence(timeout: Fixture.existenceTimeout),
            "Today summary title is not exposed"
        )
        let todayTitleMinY = todayTitle.frame.minY

        // 锚点日的日格标签包含具体节日名（徽标并入无障碍标签）
        XCTAssertTrue(
            waitForAnyButton(
                application,
                containing: Fixture.nationalDayLabel,
                timeout: Fixture.existenceTimeout
            ),
            "10/1 cell should carry 国庆节 in its badge"
        )
        XCTAssertTrue(
            waitForAnyButton(
                application,
                containing: Fixture.midAutumnLabel,
                timeout: Fixture.existenceTimeout
            ),
            "10/6 cell should carry 中秋节 in its badge"
        )
        XCTAssertTrue(
            waitForAnyButton(
                application,
                containing: Fixture.coldDewSolarTermLabel,
                timeout: Fixture.existenceTimeout
            ),
            "10/8 cell should carry the 寒露 solar term"
        )
        // 公告合并名不得出现在日格徽标或详情行
        XCTAssertFalse(
            application.buttons.matching(
                NSPredicate(
                    format: "label CONTAINS %@",
                    Fixture.combinedHolidayLabel
                )
            ).firstMatch.exists,
            "Day cells must not repeat the combined announcement name"
        )

        // 详情行：锚点日显示具体节日名 + 休
        anchorCell(application, dayText: "10 月 1 日").click()
        XCTAssertTrue(
            application.staticTexts[Fixture.nationalDayOffDetail]
                .waitForExistence(timeout: Fixture.existenceTimeout),
            "10/1 detail line should read 国庆节 · 休"
        )
        XCTAssertEqual(
            todayTitle.frame.minY,
            todayTitleMinY,
            accuracy: 0.5,
            "Selected-date holiday content must not move the today section"
        )
        // 中间日一次只归属一个节日，名称与所属锚点日一致
        anchorCell(application, dayText: "10 月 3 日").click()
        XCTAssertTrue(
            application.staticTexts[Fixture.nationalDayOffDetail]
                .waitForExistence(timeout: Fixture.existenceTimeout),
            "10/3 detail line should read 国庆节 · 休"
        )
        XCTAssertEqual(
            todayTitle.frame.minY,
            todayTitleMinY,
            accuracy: 0.5,
            "Changing selected-date detail must not move the today section"
        )
        // 中秋锚点日与之后的连续假期日使用相同名称
        anchorCell(application, dayText: "10 月 6 日").click()
        XCTAssertTrue(
            application.staticTexts[Fixture.midAutumnOffDetail]
                .waitForExistence(timeout: Fixture.existenceTimeout),
            "10/6 detail line should read 中秋节 · 休"
        )
        XCTAssertEqual(
            todayTitle.frame.minY,
            todayTitleMinY,
            accuracy: 0.5,
            "Mid-Autumn anchor must preserve the today section"
        )
        anchorCell(application, dayText: "10 月 7 日").click()
        XCTAssertTrue(
            application.staticTexts[Fixture.midAutumnOffDetail]
                .waitForExistence(timeout: Fixture.existenceTimeout),
            "10/7 detail line should read 中秋节 · 休"
        )
        XCTAssertEqual(
            todayTitle.frame.minY,
            todayTitleMinY,
            accuracy: 0.5,
            "Selected-date content changes must preserve the today anchor"
        )

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Optimized calendar panel detail layout"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        application.terminate()
    }

    /// 点击相邻月日期切换月份（闪烁回归）：9 月 29 日格在十月网格中
    /// 属于上月；点击后九月网格就位，且被选日格的农历徽标随月份
    /// 切换一并出现（模型层原子提交的端到端接线验证）。
    @MainActor
    func testAdjacentMonthDayCellSwitchesMonthWithBadges() throws {
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

        // 月选择器导航到 2025 年 10 月：该月周一起始网格的前导格
        // 为 9 月 29/30 日，且不含 9 月 1 日
        let monthPickerButton = application.buttons[
            Fixture.monthPickerAccessibilityLabel
        ]
        XCTAssertTrue(
            monthPickerButton.waitForExistence(timeout: Fixture.existenceTimeout),
            "Month picker button is not exposed to accessibility"
        )
        monthPickerButton.click()

        let previousYearButton = application.buttons[Fixture.previousYearLabel]
        XCTAssertTrue(
            previousYearButton.waitForExistence(timeout: Fixture.existenceTimeout),
            "Month picker did not present year navigation"
        )
        previousYearButton.click()

        let octoberButton = application.buttons[Fixture.octoberLabel]
        XCTAssertTrue(
            octoberButton.waitForExistence(timeout: Fixture.existenceTimeout),
            "Month picker did not present October"
        )
        octoberButton.click()

        let septemberFirstFragment = "9 月 1 日"
        let septemberTwentyNinthCell = anchorCell(
            application,
            dayText: "9 月 29 日"
        )
        XCTAssertFalse(
            application.buttons.matching(
                NSPredicate(format: "label CONTAINS %@", septemberFirstFragment)
            ).firstMatch.exists,
            "October grid must not contain September 1 leading cells"
        )

        // 点击前导格 9 月 29 日（相邻月日期）
        septemberTwentyNinthCell.click()

        // 九月网格就位（9 月 1 日为周一，属九月网格首格）
        XCTAssertTrue(
            waitForAnyButton(
                application,
                containing: septemberFirstFragment,
                timeout: Fixture.existenceTimeout
            ),
            "Clicking the adjacent cell should display September"
        )
        // 被选日回到九月网格内，农历徽标（八月初八 → 初八）随切换就位
        let selectedCell = application.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "9 月 29 日")
        ).firstMatch
        XCTAssertTrue(
            selectedCell.waitForExistence(timeout: Fixture.existenceTimeout),
            "September 29 cell should remain exposed after the switch"
        )
        XCTAssertTrue(
            selectedCell.label.contains(septemberLunarBadge),
            "Selected cell label should carry the lunar badge \(septemberLunarBadge), got: \(selectedCell.label)"
        )

        // 再次点击已选日期不得叠加系统焦点框；选中背景是唯一的
        // 视觉状态，随后截图同时覆盖日期格与右侧城市入口。
        selectedCell.click()

        for (index, screen) in XCUIScreen.screens.enumerated() {
            let screenshot = XCTAttachment(screenshot: screen.screenshot())
            screenshot.name = "\(Fixture.monthSwitchScreenshotName) "
                + "\(index + Fixture.screenNumberOffset)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }

        application.terminate()
    }

    /// 2025-09-29 为农历八月初八；无节气与节日，徽标显示农历日。
    private var septemberLunarBadge: String { "初八" }

    /// 月份切换后按“日 月”片段匹配日格按钮（标签为本地化完整日期）。
    @MainActor
    private func anchorCell(
        _ application: XCUIApplication,
        dayText: String
    ) -> XCUIElement {
        let cell = application.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", dayText)
        ).firstMatch
        XCTAssertTrue(
            cell.waitForExistence(timeout: Fixture.existenceTimeout),
            "Day cell \(dayText) is not exposed"
        )
        return cell
    }

    @MainActor
    private func waitForAnyButton(
        _ application: XCUIApplication,
        containing text: String,
        timeout: TimeInterval
    ) -> Bool {
        let button = application.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", text)
        ).firstMatch
        return button.waitForExistence(timeout: timeout)
    }

    /// 面板侧城市选择（问题 3 回归）：天气卡城市行弹出搜索 + 使用当前
    /// 位置；离线环境下防抖搜索走失败态文案。
    @MainActor
    func testCityPickerPopoverFromWeatherCard() throws {
        try throwIfSessionLocked()
        try throwIfSecureInputHeld()

        let application = XCUIApplication()
        application.launchEnvironment["CALENDA_DISABLE_NETWORK_REFRESH"] = "1"
        application.launch()
        application.activate()

        try openPanelByRealClick(application)

        let chooseCityButton = application.buttons[Fixture.chooseCityLabel]
        XCTAssertTrue(
            chooseCityButton.waitForExistence(timeout: Fixture.existenceTimeout),
            "Weather card city row is not exposed as 选择城市"
        )
        chooseCityButton.click()

        let searchField = application.textFields[
            Fixture.citySearchPlaceholder
        ]
        XCTAssertTrue(
            searchField.waitForExistence(timeout: Fixture.existenceTimeout),
            "City picker did not present the search field"
        )
        XCTAssertTrue(
            application.buttons[Fixture.useCurrentLocationLabel].exists,
            "City picker did not present 使用当前位置"
        )

        searchField.click()
        searchField.typeText("上海")
        // 防抖（350ms）+ 失败态：网络被禁用时地理编码失败显示离线文案
        XCTAssertTrue(
            application.staticTexts[Fixture.weatherOfflineText]
                .waitForExistence(timeout: Fixture.existenceTimeout),
            "Offline geocoding failure should surface in the popover"
        )

        // Escape 先关闭弹出层；面板保持，再按一次才关闭面板（附加1）
        application.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(
            waitForPanel(visible: true, timeout: Fixture.existenceTimeout),
            "Escape should close the popover, not the panel"
        )
        application.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(
            waitForPanel(visible: false, timeout: Fixture.existenceTimeout),
            "Second Escape should close the panel"
        )

        application.terminate()
    }

    /// 设置窗口（问题 1 / 附加 7）：面板内打开设置后窗口可见、
    /// 主菜单三项装配；关闭窗口恢复 accessory 形态不崩溃。
    @MainActor
    func testSettingsWindowOpensAndCloses() throws {
        try throwIfSessionLocked()

        let application = XCUIApplication()
        application.launchEnvironment["CALENDA_DISABLE_NETWORK_REFRESH"] = "1"
        application.launch()
        application.activate()

        try openPanelByRealClick(application)

        let settingsButton = application.buttons[Fixture.openSettingsLabel]
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: Fixture.existenceTimeout),
            "Settings button is not exposed"
        )
        settingsButton.click()

        // 设置窗口出现（带标题栏的普通窗口）
        let settingsWindow = application.windows[
            Fixture.settingsWindowTitle
        ]
        XCTAssertTrue(
            settingsWindow.waitForExistence(timeout: Fixture.existenceTimeout),
            "Settings window did not appear"
        )

        // ⌘W 关闭设置窗口（主菜单“窗口 > 关闭”的快捷键）：
        // 关闭后 LSUIElement 应用自然回到后台（不再前台），进程保持存活
        application.typeKey("w", modifierFlags: .command)
        let closed = NSPredicate(format: "exists == false")
        let expectation = expectation(for: closed, evaluatedWith: settingsWindow)
        wait(for: [expectation], timeout: Fixture.existenceTimeout)
        XCTAssertNotEqual(
            application.state,
            .notRunning,
            "App must stay alive after closing the settings window"
        )

        application.terminate()
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
