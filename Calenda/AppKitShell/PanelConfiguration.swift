//
//  PanelConfiguration.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import AppKit

enum PanelConfiguration {
    /// 右栏与总宽同步收窄，月历网格仍保留原有宽度和命中区域。
    static let detailColumnWidth: CGFloat = 160
    static let contentSize = CGSize(width: 590, height: 370)
    static let cornerRadius: CGFloat = 18
    static let collectionBehavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces,
        .fullScreenAuxiliary,
        .transient,
    ]
}
