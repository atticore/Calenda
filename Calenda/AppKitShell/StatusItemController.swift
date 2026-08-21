//
//  StatusItemController.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import AppKit

@MainActor
final class StatusItemController {
    private enum Presentation {
        static let iconSystemName = "calendar"
        static let fallbackDayTitle = ""
    }

    private weak var panelController: (any PanelControlling)?
    private weak var shellActions: (any ShellActions)?
    private let settings: (any SettingsProviding)?
    private let clock: any ClockProviding
    private let statusBar: NSStatusBar
    private let statusItem: NSStatusItem
    private var titleFormatter: MenuBarDateTitleFormatter
    private var midnightTimer: Timer?

    init(
        panelController: any PanelControlling,
        statusBar: NSStatusBar = .system,
        clock: any ClockProviding = SystemClock(),
        shellActions: (any ShellActions)? = nil,
        settings: (any SettingsProviding)? = nil
    ) {
        self.panelController = panelController
        self.shellActions = shellActions
        self.settings = settings
        self.clock = clock
        self.statusBar = statusBar
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        titleFormatter = MenuBarDateTitleFormatter(calendar: .autoupdatingCurrent)

        configureStatusButton()
        registerForSystemChanges()
        refresh()
        scheduleUITestPanelOpeningIfRequested()
    }

    isolated deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        midnightTimer?.invalidate()
        statusBar.removeStatusItem(statusItem)
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else {
            return
        }

        button.image = nil
        button.imagePosition = .noImage
        button.font = .monospacedDigitSystemFont(
            ofSize: NSFont.systemFontSize,
            weight: .medium
        )
        button.toolTip = AppText.menuBarAccessibilityLabel
        button.setAccessibilityLabel(AppText.menuBarAccessibilityLabel)
        button.target = self
        button.action = #selector(handleStatusItemClick)
        // 左键切换面板；右键弹出上下文菜单（设计 5.3）
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func registerForSystemChanges() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemDateChange),
            name: .NSCalendarDayChanged,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemDateChange),
            name: .NSSystemTimeZoneDidChange,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemDateChange),
            name: NSLocale.currentLocaleDidChangeNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(handleSettingsChange),
            name: .appSettingsDidChange,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemDateChange),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc
    private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu(for: sender)
        } else {
            panelController?.togglePanel(relativeTo: sender)
        }
    }

    /// UI 测试注入（设计 18.2）：副屏位于主屏上方时菜单栏项
    /// 无法命中、事件合成的负坐标点击会丢失，测试借环境变量
    /// 走与左键相同的开面板路径，保持其余断言真实。
    private func scheduleUITestPanelOpeningIfRequested() {
        guard ProcessInfo.processInfo.environment[
            "CALENDA_UI_TEST_OPEN_PANEL"
        ] == "1" else {
            return
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let button = self?.statusItem.button else {
                return
            }
            // 真实点击由 AppKit 激活应用；无障碍工具无法从外部
            // 激活后台型（accessory）应用，这里补齐同样的前置条件，
            // 使面板成为 key 窗口、Escape 等键盘路径与真实路径一致。
            NSApp.activate()
            self?.panelController?.togglePanel(relativeTo: button)
        }
    }

    /// 右键临时弹出设置菜单；不把 menu 永久赋给
    /// status item，避免吞掉左键动作（设计 5.3）。
    private func showContextMenu(for button: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            return
        }

        let menu = NSMenu()
        let settingsItem = menu.addItem(
            withTitle: AppText.openSettings,
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        )
        settingsItem.target = self
        NSMenu.popUpContextMenu(menu, with: event, for: button)
    }

    @objc
    private func openSettingsFromMenu() {
        shellActions?.openSettings()
    }

    @objc
    private func handleSystemDateChange(_ notification: Notification) {
        titleFormatter = MenuBarDateTitleFormatter(calendar: .autoupdatingCurrent)
        refresh()
    }

    @objc
    private func handleSettingsChange(_ notification: Notification) {
        refresh()
    }

    private func refreshDateTitle() {
        titleFormatter = MenuBarDateTitleFormatter(calendar: .autoupdatingCurrent)
        refresh()
    }

    private func refresh() {
        applyMenuBarStyle()
        scheduleMidnightTitleRefresh()
    }

    /// 菜单栏样式（设计 5.7/15.2）：图标加日期为默认；
    /// 仅图标时清空文字，模板图标适配深浅色。
    private func applyMenuBarStyle() {
        let style = settings?.settings.menuBarStyle ?? .iconAndDate
        switch style {
        case .iconAndDate:
            if let dateIcon = MenuBarDateIconRenderer.icon(
                day: titleFormatter.dayNumber(from: clock.now),
                calendarSymbolName: Presentation.iconSystemName
            ) {
                applyDateIcon(dateIcon)
            } else {
                applyFallbackDateTitle()
            }
        case .icon:
            applySystemIcon()
        }
    }

    /// 日期图标与文字标题互斥：切换样式时先清空另一侧，
    /// 避免旧内容残留导致宽度抖动。
    private func applyDateIcon(_ icon: NSImage) {
        guard let button = statusItem.button else {
            return
        }
        button.title = Presentation.fallbackDayTitle
        button.image = icon
        button.imagePosition = .imageOnly
    }

    /// 系统符号缺失时的回退：沿用“无图标 + 文字日期”旧样式。
    private func applyFallbackDateTitle() {
        guard let button = statusItem.button else {
            return
        }
        button.image = nil
        button.title = titleFormatter.string(from: clock.now)
    }

    private func applySystemIcon() {
        guard let button = statusItem.button else {
            return
        }
        button.image = MenuBarDateIconRenderer.plainIcon()
        button.title = Presentation.fallbackDayTitle
        button.imagePosition = .imageOnly
    }

    private func scheduleMidnightTitleRefresh() {
        midnightTimer?.invalidate()
        guard let fireDate = TimeBoundary.nextMidnight(after: clock.now) else {
            return
        }
        let timer = Timer(fire: fireDate, interval: .zero, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshDateTitle()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        midnightTimer = timer
    }
}
