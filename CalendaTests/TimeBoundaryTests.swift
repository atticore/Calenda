//
//  TimeBoundaryTests.swift
//  CalendaTests
//
//  Created by atticore on 2026/8/21.
//

import Foundation
import Testing
@testable import Calenda

struct TimeBoundaryTests {
    private enum Fixture {
        static let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
        static let justBeforeLocalMidnight = "2026-08-20T06:30:00Z"
        static let localMidnight = "2026-08-20T07:00:00Z"
    }

    @Test
    func findsMidnightInTheInjectedTimeZone() throws {
        let date = try makeInstant(Fixture.justBeforeLocalMidnight)
        let expectedBoundary = try makeInstant(Fixture.localMidnight)

        let boundary = try #require(
            TimeBoundary.nextMidnight(after: date, timeZone: Fixture.losAngeles)
        )

        #expect(boundary == expectedBoundary)
    }

    private func makeInstant(_ instant: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: instant))
    }
}
