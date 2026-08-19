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
    private let clock: any ClockProviding
    private let statusBar: NSStatusBar
    private let statusItem: NSStatusItem
    private var titleFormatter: MenuBarDateTitleFormatter

    init(
        panelController: any PanelControlling,
        statusBar: NSStatusBar = .system,
        clock: any ClockProviding = SystemClock()
    ) {
        self.panelController = panelController
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
        button.sendAction(on: .leftMouseUp)
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
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemDateChange),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc
    private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        panelController?.togglePanel(relativeTo: sender)
    }

    @objc
    private func handleSystemDateChange(_ notification: Notification) {
        titleFormatter = MenuBarDateTitleFormatter(calendar: .autoupdatingCurrent)
        refresh()
    }

    private func refresh() {
        statusItem.button?.title = titleFormatter.string(from: clock.now)
    }
}
