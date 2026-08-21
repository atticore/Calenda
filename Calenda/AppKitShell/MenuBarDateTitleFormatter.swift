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
        String(dayNumber(from: date))
    }

    /// 图标内绘制的当日数字；标题与图标共用同一来源。
    nonisolated func dayNumber(from date: Date) -> Int {
        calendar.component(.day, from: date)
    }
}
