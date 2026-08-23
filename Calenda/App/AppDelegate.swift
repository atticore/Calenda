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
    private var appMenuCoordinator: AppMenuCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settingsStore = SettingsStore()
        self.settingsStore = settingsStore

        // 同一 HolidayService / WeatherService / LocationService 实例供
        // 面板与设置页共享，保证缓存与在途任务状态唯一（设计 18.2：单实例验证）
        let holidayService = HolidayService(client: HolidayClient())
        let weatherClient = OpenMeteoClient()
        let weatherService = WeatherService(client: weatherClient)
        let locationService = SystemLocationService()

        // LSUIElement 应用平时无菜单栏；设置窗口为 key 期间切到
        // regular 策略时需要这份最小主菜单承载编辑命令（Cmd+C/V）
        let appMenuCoordinator = AppMenuCoordinator { [weak self] in
            self?.openSettings()
        }
        appMenuCoordinator.install()
        self.appMenuCoordinator = appMenuCoordinator

        let appModel = AppModel(
            settings: settingsStore,
            holidayService: holidayService,
            weatherService: weatherService,
            locationService: locationService
        )
        let panelController = PanelController(
            appModel: appModel,
            shellActions: self,
            citySearcher: weatherClient
        )
        self.panelController = panelController

        settingsWindowController = SettingsWindowController(
            settingsStore: settingsStore,
            loginItemService: LoginItemService(),
            holidayService: holidayService,
            weatherService: weatherService,
            locationService: locationService,
            citySearcher: weatherClient
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
