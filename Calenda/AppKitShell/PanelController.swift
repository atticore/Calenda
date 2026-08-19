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
    private let panel: CalendarPanel
    private let hostingView: NSHostingView<PanelShellView>
    private let positioner: any PanelPositioning
    private let clock: any ClockProviding
    private let outsideClickMonitor = OutsideClickMonitor()
    private var visibility = PanelVisibilityStateMachine()

    init(
        positioner: any PanelPositioning = PanelPositioner(),
        clock: any ClockProviding = SystemClock()
    ) {
        self.positioner = positioner
        self.clock = clock
        hostingView = NSHostingView(rootView: PanelShellView(date: clock.now))
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
        panel.orderOut(nil)
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

        let anchorInWindow = statusButton.convert(statusButton.bounds, to: nil)
        let anchorOnScreen = statusWindow.convertToScreen(anchorInWindow)
        let panelFrame = positioner.frame(
            anchor: anchorOnScreen,
            panelSize: PanelConfiguration.contentSize,
            visibleFrame: screen.visibleFrame
        )

        hostingView.rootView = PanelShellView(date: clock.now)
        panel.setFrame(panelFrame, display: false)
        NSApplication.shared.activate()
        panel.makeKeyAndOrderFront(nil)
        outsideClickMonitor.install { [weak self] reason in
            self?.closePanel(reason: reason)
        }
        visibility.finishShowing()
    }

    private func returnToHiddenState() {
        guard visibility.beginHiding() else {
            return
        }
        visibility.finishHiding()
    }
}
