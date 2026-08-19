//
//  MenuBarDateTitleFormatter.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import Foundation

struct MenuBarDateTitleFormatter: Sendable {
    private let calendar: Calendar

    nonisolated init(calendar: Calendar) {
        self.calendar = calendar
    }

    nonisolated func string(from date: Date) -> String {
        String(calendar.component(.day, from: date))
    }
}
