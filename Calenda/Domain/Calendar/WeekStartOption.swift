//
//  WeekStartOption.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

nonisolated enum WeekStartOption: Sendable {
    case system
    case monday
    case sunday

    func resolvedWeekday(systemFirstWeekday: CalendarWeekday) -> CalendarWeekday {
        switch self {
        case .system:
            systemFirstWeekday
        case .monday:
            .monday
        case .sunday:
            .sunday
        }
    }
}

