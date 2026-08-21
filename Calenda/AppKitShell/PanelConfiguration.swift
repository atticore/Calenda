//
//  PanelConfiguration.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import AppKit

enum PanelConfiguration {
    /// 紧凑菜单栏面板：为日期格保留足够命中区域，同时避免占据过多桌面。
    static let contentSize = CGSize(width: 610, height: 370)
    static let cornerRadius: CGFloat = 18
    static let collectionBehavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces,
        .fullScreenAuxiliary,
        .transient,
    ]
}
