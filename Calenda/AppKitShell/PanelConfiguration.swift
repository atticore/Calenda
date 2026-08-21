//
//  PanelConfiguration.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import AppKit

enum PanelConfiguration {
    static let contentSize = CGSize(width: 680, height: 460)
    static let maxContentSize = CGSize(width: 780, height: 560)
    static let cornerRadius: CGFloat = 18
    static let collectionBehavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces,
        .fullScreenAuxiliary,
        .transient,
    ]

    static func adaptedContentSize(fittingSize: CGSize) -> CGSize {
        CGSize(
            width: min(max(fittingSize.width, contentSize.width), maxContentSize.width),
            height: min(max(fittingSize.height, contentSize.height), maxContentSize.height)
        )
    }
}
