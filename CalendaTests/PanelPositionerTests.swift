//
//  PanelPositionerTests.swift
//  CalendaTests
//
//  Created by atticore on 2026/8/19.
//

import CoreGraphics
import Testing
@testable import Calenda

struct PanelPositionerTests {
    private enum Fixture {
        static let gap: CGFloat = 6
        static let visibleFrame = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        static let panelSize = CGSize(width: 680, height: 460)

        static let centeredAnchor = CGRect(x: 700, y: 878, width: 40, height: 22)
        static let centeredFrame = CGRect(x: 380, y: 412, width: 680, height: 460)

        static let leftEdgeAnchor = CGRect(x: 8, y: 878, width: 30, height: 22)
        static let leftEdgeFrame = CGRect(x: 0, y: 412, width: 680, height: 460)

        static let rightEdgeAnchor = CGRect(x: 1_410, y: 878, width: 24, height: 22)
        static let rightEdgeFrame = CGRect(x: 760, y: 412, width: 680, height: 460)

        static let lowAnchor = CGRect(x: 700, y: 100, width: 40, height: 22)
        static let frameAboveLowAnchor = CGRect(x: 380, y: 128, width: 680, height: 460)

        static let constrainedAnchor = CGRect(x: 700, y: 400, width: 40, height: 22)
        static let tallPanelSize = CGSize(width: 680, height: 600)
        static let constrainedFrame = CGRect(x: 380, y: 300, width: 680, height: 600)

        static let oversizedPanelSize = CGSize(width: 1_600, height: 1_000)
        static let visibleFrameSizedPanel = CGSize(width: 1_440, height: 900)
        static let visibleFrameOrigin = CGPoint(x: 0, y: 0)

        static let secondaryVisibleFrame = CGRect(x: -1_920, y: 23, width: 1_920, height: 1_057)
        static let secondaryAnchor = CGRect(x: -60, y: 1_058, width: 32, height: 22)
        static let secondaryExpectedFrame = CGRect(x: -680, y: 592, width: 680, height: 460)
    }

    private let positioner = PanelPositioner(gap: Fixture.gap)

    @Test
    func centersPanelBelowStatusItemWhenSpaceIsAvailable() {
        let frame = positioner.frame(
            anchor: Fixture.centeredAnchor,
            panelSize: Fixture.panelSize,
            visibleFrame: Fixture.visibleFrame
        )

        #expect(frame == Fixture.centeredFrame)
    }

    @Test
    func keepsPanelInsideLeftScreenEdge() {
        let frame = positioner.frame(
            anchor: Fixture.leftEdgeAnchor,
            panelSize: Fixture.panelSize,
            visibleFrame: Fixture.visibleFrame
        )

        #expect(frame == Fixture.leftEdgeFrame)
    }

    @Test
    func keepsPanelInsideRightScreenEdge() {
        let frame = positioner.frame(
            anchor: Fixture.rightEdgeAnchor,
            panelSize: Fixture.panelSize,
            visibleFrame: Fixture.visibleFrame
        )

        #expect(frame == Fixture.rightEdgeFrame)
    }

    @Test
    func placesPanelAboveAnchorWhenBelowDoesNotFit() {
        let frame = positioner.frame(
            anchor: Fixture.lowAnchor,
            panelSize: Fixture.panelSize,
            visibleFrame: Fixture.visibleFrame
        )

        #expect(frame == Fixture.frameAboveLowAnchor)
    }

    @Test
    func usesRoomierSideAndClampsWhenNeitherSideFits() {
        let frame = positioner.frame(
            anchor: Fixture.constrainedAnchor,
            panelSize: Fixture.tallPanelSize,
            visibleFrame: Fixture.visibleFrame
        )

        #expect(frame == Fixture.constrainedFrame)
    }

    @Test
    func constrainsOversizedPanelToVisibleFrame() {
        let frame = positioner.frame(
            anchor: Fixture.centeredAnchor,
            panelSize: Fixture.oversizedPanelSize,
            visibleFrame: Fixture.visibleFrame
        )

        #expect(frame.origin == Fixture.visibleFrameOrigin)
        #expect(frame.size == Fixture.visibleFrameSizedPanel)
    }

    @Test
    func positionsPanelWithinSecondaryDisplayCoordinates() {
        let frame = positioner.frame(
            anchor: Fixture.secondaryAnchor,
            panelSize: Fixture.panelSize,
            visibleFrame: Fixture.secondaryVisibleFrame
        )

        #expect(frame == Fixture.secondaryExpectedFrame)
    }
}
