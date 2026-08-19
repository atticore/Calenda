//
//  MenuBarDateTitleFormatterTests.swift
//  CalendaTests
//
//  Created by atticore on 2026/8/19.
//

import Foundation
import Testing
@testable import Calenda

struct MenuBarDateTitleFormatterTests {
    private enum Fixture {
        static let year = 2026
        static let month = 8
        static let day = 19
        static let expectedDayTitle = "19"
        static let timeZoneIdentifier = "Asia/Shanghai"
    }

    @Test
    func formatsTheCalendarDayAsTheMenuBarTitle() throws {
        let timeZone = try #require(TimeZone(identifier: Fixture.timeZoneIdentifier))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = try #require(
            calendar.date(
                from: DateComponents(
                    timeZone: timeZone,
                    year: Fixture.year,
                    month: Fixture.month,
                    day: Fixture.day
                )
            )
        )
        let formatter = MenuBarDateTitleFormatter(calendar: calendar)

        #expect(formatter.string(from: date) == Fixture.expectedDayTitle)
    }
}
