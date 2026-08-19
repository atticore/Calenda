//
//  PanelPositioner.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import CoreGraphics

struct PanelPositioner: PanelPositioning {
    private enum Metrics {
        nonisolated static let defaultGap: CGFloat = 6
    }

    private let gap: CGFloat

    nonisolated init(gap: CGFloat = Metrics.defaultGap) {
        self.gap = max(gap, .zero)
    }

    nonisolated func frame(
        anchor: CGRect,
        panelSize: CGSize,
        visibleFrame: CGRect
    ) -> CGRect {
        let availableFrame = visibleFrame.standardized
        let constrainedSize = CGSize(
            width: panelSize.width.clamped(to: .zero ... availableFrame.width),
            height: panelSize.height.clamped(to: .zero ... availableFrame.height)
        )

        let centeredOriginX = anchor.midX - constrainedSize.width / 2
        let horizontalRange = availableFrame.minX ... availableFrame.maxX - constrainedSize.width
        let originX = centeredOriginX.clamped(to: horizontalRange)
        let originY = verticalOrigin(
            anchor: anchor.standardized,
            panelHeight: constrainedSize.height,
            visibleFrame: availableFrame
        )

        return CGRect(
            origin: CGPoint(x: originX, y: originY),
            size: constrainedSize
        )
    }

    nonisolated private func verticalOrigin(
        anchor: CGRect,
        panelHeight: CGFloat,
        visibleFrame: CGRect
    ) -> CGFloat {
        let spaceBelow = max(anchor.minY - gap - visibleFrame.minY, .zero)
        let spaceAbove = max(visibleFrame.maxY - anchor.maxY - gap, .zero)
        let originBelow = anchor.minY - gap - panelHeight
        let originAbove = anchor.maxY + gap
        let verticalRange = visibleFrame.minY ... visibleFrame.maxY - panelHeight

        if spaceBelow >= panelHeight {
            return originBelow.clamped(to: verticalRange)
        }
        if spaceAbove >= panelHeight {
            return originAbove.clamped(to: verticalRange)
        }

        let preferredOrigin = spaceBelow >= spaceAbove
            ? visibleFrame.minY
            : visibleFrame.maxY - panelHeight
        return preferredOrigin.clamped(to: verticalRange)
    }
}

private extension Comparable {
    nonisolated func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
