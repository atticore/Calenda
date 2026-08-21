//
//  ShellActions.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Foundation

/// AppKit 各 controller 之间不直接互相强引用，统一经
/// AppDelegate 路由的壳层动作（设计 7.2）。
@MainActor
protocol ShellActions: AnyObject {
    func openSettings()
    func quit()
}
