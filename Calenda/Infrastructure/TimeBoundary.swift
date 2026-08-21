//
//  TimeBoundary.swift
//  Calenda
//
//  Created by atticore on 2026/8/20.
//

import Foundation

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
