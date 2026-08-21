//
//  AppDelegate.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ShellActions {
    private var panelController: PanelController?
    private var statusItemController: StatusItemController?
    private var settingsWindowController: SettingsWindowController?
    private var settingsStore: SettingsStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settingsStore = SettingsStore()
        self.settingsStore = settingsStore

        // 同一 HolidayService 实例供面板与设置页共享，保证缓存与
        // 节流状态唯一（设计 18.2：单实例验证）
        let holidayService = HolidayService(client: HolidayClient())

        let appModel = AppModel(
            settings: settingsStore,
            holidayService: holidayService
        )
        let panelController = PanelController(
            appModel: appModel,
            shellActions: self
        )
        self.panelController = panelController

        settingsWindowController = SettingsWindowController(
            settingsStore: settingsStore,
            loginItemService: LoginItemService(),
            holidayService: holidayService
        )

        statusItemController = StatusItemController(
            panelController: panelController,
            shellActions: self,
            settings: settingsStore
        )
    }

    // MARK: - ShellActions

    /// 设置窗口出现前关闭主面板（设计 15.1）；
    /// 窗口已存在时只激活置前，不重复创建。
    func openSettings() {
        panelController?.closePanel(reason: .settings)
        settingsWindowController?.show()
    }

    func quit() {
        NSApp.terminate(nil)
    }
}
