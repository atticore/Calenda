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
        static let navigationModifierFlags: NSEvent.ModifierFlags = [
            .command,
            .option,
            .control,
            .shift,
        ]
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
    private var activationPolicyBeforePanel: NSApplication.ActivationPolicy?

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
        panel.keyDownHandler = { [weak self] event in
            self?.handleCalendarKeyDown(event) ?? false
        }
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
        panel.orderOut(nil)
        appModel.panelDidDisappear()
        visibility.finishHiding()
        // 打开设置是从面板到普通窗口的连续交接；保持 regular，避免
        // accessory → regular 的连续切换让设置窗口在窗口服务器中落后。
        if case .settings = reason {
            return
        }
        restoreActivationPolicy()
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
        // accessory 应用不能稳定接收键盘：临时切到 regular，
        // 关闭面板后恢复。这只影响键盘路由；面板的可见与
        // key 状态不再依赖激活完成。
        activationPolicyBeforePanel = NSApp.activationPolicy()
        if activationPolicyBeforePanel == .accessory {
            NSApp.setActivationPolicy(.regular)
        }
        // nonactivating 面板可在应用未激活时立即成为 key 窗口：
        // 先以全透明置前并取得 key，再在同一事件循环内放开透明度。
        // 首个可见帧必然是 key 窗口，玻璃材质不会先画未激活样式、
        // 激活后变色而闪动；整个序列同步于 mouseDown，按下即见。
        panel.makeKeyAndOrderFront(nil)
        panel.contentView?.displayIfNeeded()
        panel.alphaValue = Presentation.visiblePanelAlpha
        // 激活仅为让系统把键盘事件路由给本应用（key 窗口只有
        // 活跃应用才能收键），完成时机不影响面板可见性。
        NSApp.activate(ignoringOtherApps: true)
        // 状态栏应用的面板必须显式置前，否则可能被当前活跃应用的
        // 浮层遮住，直到用户再次点击才成为最前层。
        panel.orderFrontRegardless()
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

    private func restoreActivationPolicy() {
        guard let previousPolicy = activationPolicyBeforePanel else {
            return
        }
        activationPolicyBeforePanel = nil
        guard NSApp.activationPolicy() != previousPolicy else {
            return
        }
        NSApp.setActivationPolicy(previousPolicy)
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
        // 方向键在部分键盘/事件来源下会附带 numericPad 或 function 标志；
        // 这些不是本应用的导航修饰键，不能让普通方向键匹配失败。
        let modifiers = event.modifierFlags.intersection(
            Keyboard.navigationModifierFlags
        )
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
