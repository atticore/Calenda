//
//  CalendarServiceTests.swift
//  CalendaTests
//
//  Created by atticore on 2026/8/19.
//

import Foundation
import Testing
@testable import Calenda

struct CalendarServiceTests {
    private enum Fixture {
        static let gridCellCount = 42
        static let february2026 = CalendarMonthID(year: 2026, month: 2)
        static let february2024 = CalendarMonthID(year: 2024, month: 2)
        static let december2026 = CalendarMonthID(year: 2026, month: 12)
        static let today = CalendarDayID(year: 2026, month: 2, day: 14)
        static let invalidDay = CalendarDayID(year: 2026, month: 2, day: 30)
        static let december31 = CalendarDayID(year: 2026, month: 12, day: 31)
        static let january1 = CalendarDayID(year: 2027, month: 1, day: 1)
        static let daylightSavingStartEve = CalendarDayID(year: 2026, month: 3, day: 7)
        static let daylightSavingStart = CalendarDayID(year: 2026, month: 3, day: 8)
        static let daylightSavingEndEve = CalendarDayID(year: 2026, month: 10, day: 31)
        static let daylightSavingEnd = CalendarDayID(year: 2026, month: 11, day: 1)
        static let dayAfterDaylightSavingEnd = CalendarDayID(year: 2026, month: 11, day: 2)
        static let utc = TimeZone(secondsFromGMT: 0)!
        static let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
    }

    @Test
    func generatesMondayFirstGridAcrossMonthBoundaries() throws {
        let service = CalendarService(timeZone: Fixture.utc)

        let cells = try service.cells(
            for: Fixture.february2026,
            today: Fixture.today,
            weekStart: .monday
        )

        #expect(cells.count == Fixture.gridCellCount)
        #expect(cells.first?.id == CalendarDayID(year: 2026, month: 1, day: 26))
        #expect(cells.last?.id == CalendarDayID(year: 2026, month: 3, day: 8))
        #expect(cells.filter(\.isInDisplayedMonth).count == 28)
        #expect(cells.filter(\.isToday).map(\.id) == [Fixture.today])
    }

    @Test
    func generatesSundayFirstGrid() throws {
        let service = CalendarService(timeZone: Fixture.utc)

        let cells = try service.cells(
            for: Fixture.february2026,
            today: Fixture.today,
            weekStart: .sunday
        )

        #expect(cells.first?.id == CalendarDayID(year: 2026, month: 2, day: 1))
        #expect(cells.last?.id == CalendarDayID(year: 2026, month: 3, day: 14))
    }

    @Test
    func followsInjectedSystemWeekStart() throws {
        let service = CalendarService(
            timeZone: Fixture.utc,
            systemFirstWeekday: .sunday
        )

        let cells = try service.cells(
            for: Fixture.february2026,
            today: Fixture.today,
            weekStart: .system
        )

        #expect(cells.first?.id == CalendarDayID(year: 2026, month: 2, day: 1))
    }

    @Test
    func includesLeapDayAndAlwaysProducesSixWeeks() throws {
        let service = CalendarService(timeZone: Fixture.utc)

        let cells = try service.cells(
            for: Fixture.february2024,
            today: CalendarDayID(year: 2024, month: 2, day: 29),
            weekStart: .monday
        )

        #expect(cells.count == Fixture.gridCellCount)
        #expect(cells.contains { $0.id == CalendarDayID(year: 2024, month: 2, day: 29) })
        #expect(cells.filter(\.isInDisplayedMonth).count == 29)
    }

    @Test
    func generatesConsecutiveUniqueDaysAcrossYearBoundary() throws {
        let service = CalendarService(timeZone: Fixture.utc)

        let cells = try service.cells(
            for: Fixture.december2026,
            today: CalendarDayID(year: 2026, month: 12, day: 31),
            weekStart: .monday
        )

        #expect(cells.first?.id == CalendarDayID(year: 2026, month: 11, day: 30))
        #expect(cells.last?.id == CalendarDayID(year: 2027, month: 1, day: 10))
        #expect(Set(cells.map(\.id)).count == Fixture.gridCellCount)
    }

    @Test
    func convertsAnInstantUsingTheConfiguredTimeZone() throws {
        let instant = try #require(
            ISO8601DateFormatter().date(from: "2026-08-19T02:00:00Z")
        )
        let utcService = CalendarService(timeZone: Fixture.utc)
        let losAngelesService = CalendarService(timeZone: Fixture.losAngeles)

        #expect(utcService.dayID(for: instant) == CalendarDayID(year: 2026, month: 8, day: 19))
        #expect(
            losAngelesService.dayID(for: instant)
                == CalendarDayID(year: 2026, month: 8, day: 18)
        )
    }

    @Test
    func noonDateRoundTripsThroughDayIDAtNoon() throws {
        let service = CalendarService(timeZone: Fixture.utc)
        let day = CalendarDayID(year: 2026, month: 8, day: 19)

        let noonDate = try #require(service.noonDate(for: day))

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = Fixture.utc
        #expect(service.dayID(for: noonDate) == day)
        #expect(utcCalendar.component(.hour, from: noonDate) == 12)
    }

    @Test
    func movesDaysAcrossTheYearBoundary() {
        let service = CalendarService(timeZone: Fixture.utc)

        #expect(service.day(byAdding: 1, to: Fixture.december31) == Fixture.january1)
        #expect(service.day(byAdding: -1, to: Fixture.january1) == Fixture.december31)
    }

    @Test
    func movesDaysAcrossDaylightSavingBoundaries() {
        let service = CalendarService(timeZone: Fixture.losAngeles)

        #expect(
            service.day(byAdding: 1, to: Fixture.daylightSavingStartEve)
                == Fixture.daylightSavingStart
        )
        #expect(
            service.day(byAdding: 1, to: Fixture.daylightSavingEndEve)
                == Fixture.daylightSavingEnd
        )
        #expect(
            service.day(byAdding: 1, to: Fixture.daylightSavingEnd)
                == Fixture.dayAfterDaylightSavingEnd
        )
    }

    @Test
    func rejectsInvalidDaysWhenMovingThem() {
        let service = CalendarService(timeZone: Fixture.utc)

        #expect(service.day(byAdding: 1, to: Fixture.invalidDay) == nil)
    }

    @Test
    func rejectsInvalidDisplayedMonth() {
        let service = CalendarService(timeZone: Fixture.utc)
        let invalidMonth = CalendarMonthID(year: 2026, month: 13)

        #expect(throws: CalendarServiceError.invalidMonth(invalidMonth)) {
            try service.cells(
                for: invalidMonth,
                today: Fixture.today,
                weekStart: .monday
            )
        }
    }
}
