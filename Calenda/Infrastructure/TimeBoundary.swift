//
//  TimeBoundary.swift
//  Calenda
//
//  Created by atticore on 2026/8/20.
//

import Foundation

nonisolated enum HolidayYearWindow {
    static func visibleYears(
        from date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Set<Int> {
        let currentYear = calendar.component(.year, from: date)
        let nextYear = currentYear + CalendarYearOffset.next
        return [currentYear, nextYear]
    }

    private enum CalendarYearOffset {
        static let next = 1
    }
}

nonisolated enum TimeBoundary {
    static func nextMidnight(
        after date: Date,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.nextDate(
            after: date,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        )
    }

    static func nextMinute(
        after date: Date,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.nextDate(
            after: date,
            matching: DateComponents(second: 0),
            matchingPolicy: .nextTime
        )
    }
}
