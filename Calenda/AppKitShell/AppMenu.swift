//
//  AppMenu.swift
//  Calenda
//
//  Created by atticore on 2026/8/22.
//

import AppKit

/// 装配并持有最小主菜单（应用 / 编辑 / 窗口）。
///
/// Calenda 是 LSUIElement（accessory）应用，平时不显示菜单栏；
/// 设置窗口为 key 期间会临时切换为 regular 策略，此时菜单栏出现。
/// 没有主菜单时编辑命令（Cmd+C/V/X/A）不会作用到文本框，
/// 因此启动时就要装配好这份菜单。
@MainActor
final class AppMenuCoordinator {
    private let openSettings: () -> Void

    init(openSettings: @escaping () -> Void) {
        self.openSettings = openSettings
    }

    func install() {
        NSApp.mainMenu = makeMainMenu()
    }

    // MARK: - 菜单构建

    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        mainMenu.addItem(appMenu)
        mainMenu.addItem(editMenu)
        mainMenu.addItem(windowMenu)
        return mainMenu
    }

    private var appMenu: NSMenuItem {
        let item = NSMenuItem()
        item.submenu = appSubmenu
        return item
    }

    private var appSubmenu: NSMenu {
        let menu = NSMenu()
        menu.addItem(
            menuItem(
                title: AppText.menuAbout,
                action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                keyEquivalent: ""
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            menuItem(
                title: AppText.menuSettingsItem,
                target: self,
                action: #selector(openSettingsFromMenu),
                keyEquivalent: ","
            )
        )
        menu.addItem(.separator())
        // terminate: 由 NSApplication 实现，nil target 走响应链送达
        menu.addItem(
            menuItem(
                title: AppText.menuQuitApp,
                action: #selector(NSApplication.terminate),
                keyEquivalent: "q"
            )
        )
        return menu
    }

    private var editMenu: NSMenuItem {
        let item = NSMenuItem()
        item.submenu = NSMenu(title: AppText.menuEdit)
        // 编辑命令全部 nil target：经响应链交给当前焦点文本框
        item.submenu?.addItem(
            menuItem(title: AppText.menuUndo, action: Selector(("undo:")), keyEquivalent: "z")
        )
        item.submenu?.addItem(
            menuItem(
                title: AppText.menuRedo,
                action: Selector(("redo:")),
                keyEquivalent: "Z"
            )
        )
        item.submenu?.addItem(.separator())
        item.submenu?.addItem(
            menuItem(title: AppText.menuCut, action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        )
        // 显式 ( _: ) 形式：NSText.copy 会解析到 NSObject 的
        // NSCopying copy()（selector 无冒号），无法沿响应链路由
        item.submenu?.addItem(
            menuItem(title: AppText.menuCopy, action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        )
        item.submenu?.addItem(
            menuItem(title: AppText.menuPaste, action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        )
        item.submenu?.addItem(
            menuItem(
                title: AppText.menuSelectAll,
                action: #selector(NSText.selectAll(_:)),
                keyEquivalent: "a"
            )
        )
        return item
    }

    private var windowMenu: NSMenuItem {
        let item = NSMenuItem()
        item.submenu = NSMenu(title: AppText.menuWindow)
        item.submenu?.addItem(
            menuItem(
                title: AppText.menuMinimize,
                action: #selector(NSWindow.performMiniaturize),
                keyEquivalent: "m"
            )
        )
        item.submenu?.addItem(
            menuItem(
                title: AppText.menuZoom,
                action: #selector(NSWindow.performZoom),
                keyEquivalent: ""
            )
        )
        item.submenu?.addItem(.separator())
        item.submenu?.addItem(
            menuItem(
                title: AppText.menuClose,
                action: #selector(NSWindow.performClose),
                keyEquivalent: "w"
            )
        )
        return item
    }

    private func menuItem(
        title: String,
        target: AnyObject? = nil,
        action: Selector,
        keyEquivalent: String
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: title,
            action: action,
            keyEquivalent: keyEquivalent
        )
        item.target = target
        return item
    }

    @objc
    private func openSettingsFromMenu() {
        openSettings()
    }
}
