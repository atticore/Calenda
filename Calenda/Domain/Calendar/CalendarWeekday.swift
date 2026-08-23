//
//  CalendarWeekday.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

nonisolated enum CalendarWeekday: Int, CaseIterable, Sendable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    static func ordered(startingWith firstWeekday: CalendarWeekday) -> [CalendarWeekday] {
        let weekdays = allCases
        guard let firstIndex = weekdays.firstIndex(of: firstWeekday) else {
            return weekdays
        }
        return Array(weekdays[firstIndex...]) + Array(weekdays[..<firstIndex])
    }

    var isWeekend: Bool {
        self == .saturday || self == .sunday
    }
}
