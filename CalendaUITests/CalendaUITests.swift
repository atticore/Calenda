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
        static let applicationBundleIdentifier = "com.atticore.Calenda"
        static let foregroundApplicationBundleIdentifier = "com.apple.finder"
        static let existenceTimeout: TimeInterval = 5
        static let hittablePollTimeout: TimeInterval = 1.5
        static let pollInterval: TimeInterval = 0.2
        static let panelVisibilityPollInterval: TimeInterval = 0.01
        static let visiblePanelAlphaThreshold = 0.99
        static let floatingWindowLevel = NSWindow.Level.floating.rawValue

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
        static let weatherLocationChangeLabel = "更改天气位置"
        static let weatherLocationPickerTitle = "选择天气位置"
        static let restoreDefaultCityLabel = "恢复默认城市"
        static let openSettingsLabel = "设置"
        static let settingsWindowTitle = "设置"
        static let todayTitleIdentifier = "calendar.detail.today-title"
        static let selectedDateLabel = "所选日期"
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

    /// 按下即开 + 菜单栏空白关闭（交互细化）：
    /// 1. 状态项在 mouseDown 按住期间（未抬起）面板即出现；
    /// 2. 面板打开时点击主屏菜单栏空白条带应关闭面板。
    @MainActor
    func testPressOpensPanelAndMenuBarBlankClickCloses() throws {
        try throwIfSessionLocked()

        let application = XCUIApplication()
        application.launchEnvironment["CALENDA_DISABLE_NETWORK_REFRESH"] = "1"
        application.launch()
        XCUIApplication(
            bundleIdentifier: Fixture.foregroundApplicationBundleIdentifier
        ).activate()

        let foregroundDeadline = Date().addingTimeInterval(
            Fixture.existenceTimeout
        )
        while NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            == Fixture.applicationBundleIdentifier,
            Date() < foregroundDeadline {
            Thread.sleep(forTimeInterval: Fixture.panelVisibilityPollInterval)
        }
        XCTAssertNotEqual(
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            Fixture.applicationBundleIdentifier,
            "测试按下前 Calenda 应处于未激活态"
        )

        let item = try hittableStatusItem(on: application)

        // 1. 按住状态项 3 秒不抬起；后台观察线程只在前 2.2 秒轮询，
        //    足以区分"按下即开"与"抬起才开"（抬起发生在 3 秒末）。
        //    面板可见允许先于应用激活完成（nonactivating 面板先取
        //    key 再显示，首帧即激活样式）；激活样式由下方截图佐证。
        let probe = PanelOpenProbe()
        let poller = Thread(block: {
            let stopAt = Date().addingTimeInterval(2.2)
            while Date() < stopAt {
                let panelAlpha = Self.panelWindowAlpha()
                probe.sample(
                    panelIsVisible: panelAlpha.map {
                        $0 >= Fixture.visiblePanelAlphaThreshold
                    } ?? false
                )
                if probe.openedWhilePressed {
                    break
                }
                Thread.sleep(
                    forTimeInterval: Fixture.panelVisibilityPollInterval
                )
            }
        })
        poller.start()
        item.press(forDuration: 3)

        XCTAssertTrue(
            probe.openedWhilePressed,
            "面板应在状态项按下期间（未抬起）即打开"
        )
        XCTAssertTrue(
            waitForPanel(visible: true, timeout: Fixture.existenceTimeout),
            "抬起鼠标后面板应保持打开"
        )
        let panelWindow = application.windows.matching(
            NSPredicate(format: "title == %@", Fixture.accessibilityLabel)
        ).firstMatch
        let activePanelScreenshot = XCTAttachment(
            screenshot: panelWindow.exists
                ? panelWindow.screenshot()
                : XCUIScreen.main.screenshot()
        )
        activePanelScreenshot.name =
            "Active panel opened from inactive application"
        activePanelScreenshot.lifetime = .keepAlways
        add(activePanelScreenshot)

        // 2. 点击主屏菜单栏中段空白（避开左侧应用菜单、中央刘海与
        //    右侧系统状态项；该点不关联任何 NSWindow，只能经本地
        //    监听的菜单栏条带判定关闭）。XCUIScreen 无坐标构造器，
        //    以状态项中心为基准水平偏移到屏幕宽度 45% 处：x 轴在
        //    两种坐标系下方向一致，状态项纵向中心必在菜单栏内。
        let screenWidth = NSScreen.main?.frame.width ?? item.frame.maxX
        let horizontalShift = screenWidth * 0.45 - item.frame.midX
        item.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .withOffset(CGVector(dx: horizontalShift, dy: 0))
            .click()

        XCTAssertTrue(
            waitForPanel(visible: false, timeout: Fixture.existenceTimeout),
            "点击菜单栏空白处应关闭面板"
        )

        application.terminate()
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

    /// 方向键导航：左右移动一天、上下移动一周，往返断言所选日期
    /// 无障碍标签随之变化并回到原值。与 Escape 用例同一条本地
    /// 监视器链路，环境限制（锁屏、Secure Input、AX 不可见）同样跳过。
    @MainActor
    func testArrowKeysMoveSelectedDay() throws {
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

        let selectedDate = application.descendants(matching: .any)
            .matching(
                NSPredicate(format: "label BEGINSWITH %@", Fixture.selectedDateLabel)
            )
            .firstMatch
        XCTAssertTrue(
            selectedDate.waitForExistence(timeout: Fixture.existenceTimeout),
            "Selected date element is not exposed"
        )
        let initialLabel = selectedDate.label

        // → 所选日期变化；← 回到原值
        application.typeKey(.rightArrow, modifierFlags: [])
        XCTAssertTrue(
            waitForSelectedDateLabel(
                toDifferFrom: initialLabel,
                on: selectedDate
            ),
            "Right arrow did not move the selected day"
        )

        application.typeKey(.leftArrow, modifierFlags: [])
        XCTAssertTrue(
            waitForSelectedDateLabel(
                toEqual: initialLabel,
                on: selectedDate
            ),
            "Left arrow did not restore the selected day"
        )

        // ↓ 所选日期变化；↑ 回到原值
        application.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(
            waitForSelectedDateLabel(
                toDifferFrom: initialLabel,
                on: selectedDate
            ),
            "Down arrow did not move the selected day by a week"
        )

        application.typeKey(.upArrow, modifierFlags: [])
        XCTAssertTrue(
            waitForSelectedDateLabel(
                toEqual: initialLabel,
                on: selectedDate
            ),
            "Up arrow did not restore the selected day"
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

    /// 设置页天气位置（问题 4 回归）：位置选择直接进入搜索面板，
    /// 默认城市状态不显示无意义的“恢复默认城市”操作。
    @MainActor
    func testSettingsWeatherLocationPicker() throws {
        try throwIfSessionLocked()

        let application = XCUIApplication()
        application.launchEnvironment["CALENDA_DISABLE_NETWORK_REFRESH"] = "1"
        application.launchEnvironment["CALENDA_UI_TEST_USE_DEFAULT_CITY"] = "1"
        application.launch()
        application.activate()

        try openPanelByRealClick(application)

        let settingsButton = application.buttons[Fixture.openSettingsLabel]
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: Fixture.existenceTimeout),
            "Settings button was not exposed"
        )
        settingsButton.click()

        let settingsWindow = application.windows[
            Fixture.settingsWindowTitle
        ]
        XCTAssertTrue(
            settingsWindow.waitForExistence(timeout: Fixture.existenceTimeout),
            "Settings window did not appear"
        )

        let changeLocationButton = settingsWindow.buttons[
            Fixture.weatherLocationChangeLabel
        ]
        XCTAssertTrue(
            changeLocationButton.waitForExistence(
                timeout: Fixture.existenceTimeout
            ),
            "Weather location change action was not exposed"
        )
        changeLocationButton.click()

        XCTAssertTrue(
            settingsWindow.staticTexts[
                Fixture.weatherLocationPickerTitle
            ].waitForExistence(timeout: Fixture.existenceTimeout),
            "Weather location picker did not appear"
        )
        XCTAssertTrue(
            settingsWindow.textFields[Fixture.citySearchPlaceholder].exists,
            "Weather location picker did not focus the city search field"
        )
        XCTAssertTrue(
            settingsWindow.buttons[Fixture.useCurrentLocationLabel].exists,
            "Weather location picker did not expose 使用当前位置"
        )
        XCTAssertFalse(
            settingsWindow.buttons[Fixture.restoreDefaultCityLabel].exists,
            "Default city should not show 恢复默认城市"
        )

        let pickerScreenshot = XCTAttachment(
            screenshot: XCUIScreen.main.screenshot()
        )
        pickerScreenshot.name = "Weather location picker"
        pickerScreenshot.lifetime = .keepAlways
        add(pickerScreenshot)

        application.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(
            settingsWindow.exists,
            "Escape should close the picker without closing settings"
        )

        application.terminate()
    }

    // MARK: - 共用打开路径

    /// 可命中的状态项实例；找不到（副屏在主屏上方、菜单栏拥挤溢出
    /// 等环境）时终止应用并跳过——真实指针交互无法替代。
    @MainActor
    private func hittableStatusItem(
        on application: XCUIApplication
    ) throws -> XCUIElement {
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

        guard let statusItem else {
            application.terminate()
            throw XCTSkip(
                "Status item is not hittable (secondary display above primary "
                    + "or menu bar overflow); pointer interaction cannot run"
            )
        }
        return statusItem
    }

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

    // MARK: - 所选日期标签轮询

    /// typeKey 合成事件送达与 SwiftUI 重渲染之间存在延迟，标签断言
    /// 需要轮询而不是即时比较。
    @MainActor
    private func waitForSelectedDateLabel(
        toEqual expected: String,
        on element: XCUIElement,
        timeout: TimeInterval = Fixture.existenceTimeout
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.label == expected { return true }
            Thread.sleep(forTimeInterval: Fixture.pollInterval)
        }
        return element.label == expected
    }

    @MainActor
    private func waitForSelectedDateLabel(
        toDifferFrom original: String,
        on element: XCUIElement,
        timeout: TimeInterval = Fixture.existenceTimeout
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.label != original { return true }
            Thread.sleep(forTimeInterval: Fixture.pollInterval)
        }
        return element.label != original
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
        Self.panelWindowInfo() != nil
    }

    private static func panelWindowAlpha() -> Double? {
        (panelWindowInfo()?["kCGWindowAlpha"] as? NSNumber)?.doubleValue
    }

    private static func panelWindowInfo() -> [String: Any]? {
        guard
            let list = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly],
                kCGNullWindowID
            ) as? [[String: Any]]
        else {
            return nil
        }
        return list.first { info in
            guard (info["kCGWindowOwnerName"] as? String) == "Calenda",
                  (info["kCGWindowLayer"] as? Int)
                    == Fixture.floatingWindowLevel
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

/// 后台轮询线程与测试主线程之间的面板可见性探针。
/// `@unchecked Sendable` 的不变量：所有可变状态仅经 NSLock 访问。
private final class PanelOpenProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var opened = false

    var openedWhilePressed: Bool {
        lock.withLock { opened }
    }

    func sample(panelIsVisible: Bool) {
        guard panelIsVisible else {
            return
        }
        lock.withLock {
            opened = true
        }
    }
}
