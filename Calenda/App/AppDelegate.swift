//
//  AppDelegate.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: PanelController?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panelController = PanelController()
        self.panelController = panelController
        statusItemController = StatusItemController(panelController: panelController)
    }
}
