//
//  CalendaUITests.swift
//  CalendaUITests
//
//  Created by atticore on 2026/8/19.
//

import XCTest

final class CalendaUITests: XCTestCase {
    private enum Fixture {
        static let accessibilityLabel = "Calenda 日历"
        static let existenceTimeout: TimeInterval = 5
    }

    @MainActor
    func testStatusItemOpensAndClosesPanel() {
        continueAfterFailure = false
        let application = XCUIApplication()
        application.launch()

        let statusItem = application.statusItems[Fixture.accessibilityLabel]
        XCTAssertTrue(
            statusItem.waitForExistence(timeout: Fixture.existenceTimeout),
            "Calenda status item did not appear"
        )

        statusItem.click()
        let panel = application.windows[Fixture.accessibilityLabel]
        XCTAssertTrue(
            panel.waitForExistence(timeout: Fixture.existenceTimeout),
            "Calendar panel did not appear"
        )

        application.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(
            panel.waitForNonExistence(timeout: Fixture.existenceTimeout),
            "Calendar panel did not close after Escape"
        )
    }
}
