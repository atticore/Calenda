//
//  PanelConfiguration.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import AppKit

enum PanelConfiguration {
    static let contentSize = CGSize(width: 680, height: 460)
    static let cornerRadius: CGFloat = 18
    static let collectionBehavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces,
        .fullScreenAuxiliary,
        .transient,
    ]
}
