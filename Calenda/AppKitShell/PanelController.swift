//
//  PanelController.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import AppKit
import SwiftUI

@MainActor
final class PanelController: PanelControlling {
    private enum Presentation {
        static let hiddenPanelAlpha: CGFloat = 0
        static let visiblePanelAlpha: CGFloat = 1
        static let keyWindowRetryLimit = 4
        static let nextKeyWindowAttemptOffset = 1
    }

    private enum Keyboard {
        static let leftArrowKeyCode: UInt16 = 123
        static let rightArrowKeyCode: UInt16 = 124
        static let downArrowKeyCode: UInt16 = 125
        static let upArrowKeyCode: UInt16 = 126
        static let returnToTodayCharacter = "t"
        static let openSettingsCharacter = ","
        static let quitCharacter = "q"
        static let previousDayOffset = -1
        static let nextDayOffset = 1
        static let previousWeekOffset = -7
        static let nextWeekOffset = 7
        static let previousMonthOffset = -1
        static let nextMonthOffset = 1
        static let monthsPerYear = 12
        static let previousYearOffset = -monthsPerYear
        static let nextYearOffset = monthsPerYear
    }

    private enum CalendarKeyboardCommand {
        case moveSelectedDay(Int)
        case moveDisplayedMonth(Int)
        case returnToToday
        case openSettings
        case quit
    }

    private let panel: CalendarPanel
    private let hostingView: NSHostingView<PanelShellView>
    private let positioner: any PanelPositioning
    private let appModel: AppModel
    private weak var shellActions: (any ShellActions)?
    private let outsideClickMonitor = OutsideClickMonitor()
    private var visibility = PanelVisibilityStateMachine()

    init(
        positioner: any PanelPositioning = PanelPositioner(),
        appModel: AppModel = AppModel(),
        shellActions: (any ShellActions)? = nil,
        citySearcher: (any CitySearching)? = nil
    ) {
        self.positioner = positioner
        self.appModel = appModel
        self.shellActions = shellActions
        let cityPicker = citySearcher.map { searcher in
            CityPickerActions(
                searcher: searcher,
                select: { [weak appModel] city in
                    appModel?.selectCity(city)
                },
                useCurrentLocation: { [weak appModel] in
                    appModel?.useCurrentLocation()
                }
            )
        }
        hostingView = NSHostingView(
            rootView: PanelShellView(
                model: appModel,
                openSettings: { [weak shellActions] in
                    shellActions?.openSettings()
                },
                cityPicker: cityPicker
            )
        )
        panel = CalendarPanel(hostedContentView: hostingView)
    }

    func togglePanel(relativeTo statusButton: NSStatusBarButton) {
        switch visibility.state {
        case .hidden:
            showPanel(relativeTo: statusButton)
        case .showing, .visible:
            closePanel(reason: .toggle)
        case .hiding:
            break
        }
    }

    func closePanel(reason: PanelCloseReason) {
        guard visibility.beginHiding() else {
            return
        }

        outsideClickMonitor.remove()
        panel.alphaValue = Presentation.visiblePanelAlpha
        panel.orderOut(nil)
        appModel.panelDidDisappear()
        visibility.finishHiding()
    }

    private func showPanel(relativeTo statusButton: NSStatusBarButton) {
        guard visibility.beginShowing() else {
            return
        }
        guard
            let statusWindow = statusButton.window,
            let screen = statusWindow.screen ?? NSScreen.main
        else {
            returnToHiddenState()
            return
        }

        appModel.panelWillAppear()

        let anchorInWindow = statusButton.convert(statusButton.bounds, to: nil)
        let anchorOnScreen = statusWindow.convertToScreen(anchorInWindow)
        let panelFrame = positioner.frame(
            anchor: anchorOnScreen,
            panelSize: PanelConfiguration.contentSize,
            visibleFrame: screen.visibleFrame
        )

        panel.setFrame(panelFrame, display: false)
        panel.alphaValue = Presentation.hiddenPanelAlpha
        // 点击状态项是明确的用户意图：macOS 14+ 的协作式 activate()
        // 会被系统在“前台应用持有键盘焦点”时拒绝，结果面板看得见、
        // 键盘事件却仍路由给原前台应用。activate(ignoringOtherApps:)
        // 的弃用理由是阻止*无用户交互*时抢焦点；用户主动点击正是
        // 该 API 仍然可靠的老场景（成熟菜单栏应用的通行做法），
        // 这里有意选用并接受弃用诊断。
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        // 状态栏应用的面板必须显式置前，否则可能被当前活跃应用的
        // 浮层遮住，直到用户再次点击才成为最前层。
        panel.orderFrontRegardless()
        revealPanelWhenReady()
        outsideClickMonitor.install(
            panel: panel,
            anchorWindow: statusWindow,
            closeHandler: { [weak self] reason in
                self?.closePanel(reason: reason)
            },
            keyDownHandler: { [weak self] event in
                self?.handleCalendarKeyDown(event) ?? false
            },
            ignoresGlobalClick: { [weak appModel] in
                appModel?.isResolvingCurrentLocation ?? false
            }
        )
        visibility.finishShowing()
    }

    private func returnToHiddenState() {
        guard visibility.beginHiding() else {
            return
        }
        visibility.finishHiding()
    }

    /// 先等待面板完成激活与 key window 切换，再让用户看到它，避免
    /// NSGlassEffectView 先绘制未激活样式、随后切换为激活样式而闪烁。
    private func revealPanelWhenReady(attempt: Int = .zero) {
        guard panel.isVisible else {
            return
        }

        if NSApp.isActive, panel.isKeyWindow {
            panel.alphaValue = Presentation.visiblePanelAlpha
            return
        }

        guard attempt < Presentation.keyWindowRetryLimit else {
            panel.alphaValue = Presentation.visiblePanelAlpha
            return
        }

        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, self.panel.isVisible else {
                return
            }
            self.panel.makeKeyAndOrderFront(nil)
            self.revealPanelWhenReady(
                attempt: attempt + Presentation.nextKeyWindowAttemptOffset
            )
        }
    }

    private func handleCalendarKeyDown(_ event: NSEvent) -> Bool {
        guard let command = calendarKeyboardCommand(for: event) else {
            return false
        }

        switch command {
        case let .moveSelectedDay(offset):
            appModel.moveSelectedDay(by: offset)
        case let .moveDisplayedMonth(offset):
            appModel.moveDisplayedMonth(by: offset)
        case .returnToToday:
            appModel.returnToToday()
        case .openSettings:
            shellActions?.openSettings()
        case .quit:
            shellActions?.quit()
        }
        return true
    }

    private func calendarKeyboardCommand(
        for event: NSEvent
    ) -> CalendarKeyboardCommand? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers == .command,
           let character = event.charactersIgnoringModifiers?.lowercased() {
            switch character {
            case Keyboard.returnToTodayCharacter:
                return .returnToToday
            case Keyboard.openSettingsCharacter:
                return .openSettings
            case Keyboard.quitCharacter:
                return .quit
            default:
                break
            }
        }

        switch (modifiers, event.keyCode) {
        case ([], Keyboard.leftArrowKeyCode):
            return .moveSelectedDay(Keyboard.previousDayOffset)
        case ([], Keyboard.rightArrowKeyCode):
            return .moveSelectedDay(Keyboard.nextDayOffset)
        case ([], Keyboard.upArrowKeyCode):
            return .moveSelectedDay(Keyboard.previousWeekOffset)
        case ([], Keyboard.downArrowKeyCode):
            return .moveSelectedDay(Keyboard.nextWeekOffset)
        case (.command, Keyboard.leftArrowKeyCode):
            return .moveDisplayedMonth(Keyboard.previousMonthOffset)
        case (.command, Keyboard.rightArrowKeyCode):
            return .moveDisplayedMonth(Keyboard.nextMonthOffset)
        case (.option, Keyboard.leftArrowKeyCode):
            return .moveDisplayedMonth(Keyboard.previousYearOffset)
        case (.option, Keyboard.rightArrowKeyCode):
            return .moveDisplayedMonth(Keyboard.nextYearOffset)
        default:
            return nil
        }
    }
}
