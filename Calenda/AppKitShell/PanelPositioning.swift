//
//  PanelPositioning.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import CoreGraphics

protocol PanelPositioning: Sendable {
    nonisolated func frame(
        anchor: CGRect,
        panelSize: CGSize,
        visibleFrame: CGRect
    ) -> CGRect
}
