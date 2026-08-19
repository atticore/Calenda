//
//  CalendarCellModel.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

nonisolated struct CalendarCellModel: Identifiable, Equatable, Sendable {
    let id: CalendarDayID
    let isInDisplayedMonth: Bool
    let isToday: Bool
}

