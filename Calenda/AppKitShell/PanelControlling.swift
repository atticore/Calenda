//
//  PanelControlling.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import AppKit

enum PanelCloseReason: Sendable {
    case toggle
    case outsideClick
    case escape
    case applicationDeactivated
}

@MainActor
protocol PanelControlling: AnyObject {
    func togglePanel(relativeTo statusButton: NSStatusBarButton)
    func closePanel(reason: PanelCloseReason)
}
