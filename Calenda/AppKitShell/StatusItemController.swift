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

        let image = NSImage(
            systemSymbolName: Presentation.iconSystemName,
            accessibilityDescription: AppText.menuBarAccessibilityLabel
        )
        image?.isTemplate = true

        button.image = image
        button.imagePosition = .imageLeading
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

    /// 右键临时弹出设置与退出菜单；不把 menu 永久赋给
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
        menu.addItem(.separator())
        let quitItem = menu.addItem(
            withTitle: AppText.quitApp,
            action: #selector(quitFromMenu),
            keyEquivalent: "q"
        )
        quitItem.target = self

        NSMenu.popUpContextMenu(menu, with: event, for: button)
    }

    @objc
    private func openSettingsFromMenu() {
        shellActions?.openSettings()
    }

    @objc
    private func quitFromMenu() {
        shellActions?.quit()
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
            statusItem.button?.title = titleFormatter.string(from: clock.now)
        case .icon:
            statusItem.button?.title = ""
        }
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
