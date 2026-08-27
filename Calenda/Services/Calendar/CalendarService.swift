//
//  CalendarService.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import Foundation

nonisolated enum CalendarServiceError: Error, Equatable, Sendable {
    case invalidMonth(CalendarMonthID)
    case dateCalculationFailed
}

nonisolated struct CalendarService: Sendable {
    private enum Rule {
        static let firstMonth = 1
        static let lastMonth = 12
        static let firstDayOfMonth = 1
        static let noonHour = 12
        static let daysPerWeek = 7
        static let gridCellCount = 42
    }

    private let timeZone: TimeZone
    private let systemFirstWeekday: CalendarWeekday
    /// 热路径（noonDate/dayID/键盘移动）复用的已配置 Calendar；
    /// timeZone 与 systemFirstWeekday 在 init 时即冻结，
    /// 每次调用重建并重配 Calendar 是纯开销。
    private let reuseCalendar: Calendar

    var configuredTimeZone: TimeZone {
        timeZone
    }

    init(
        timeZone: TimeZone = .autoupdatingCurrent,
        systemFirstWeekday: CalendarWeekday? = nil
    ) {
        self.timeZone = timeZone
        let resolvedFirstWeekday = systemFirstWeekday
            ?? CalendarWeekday(rawValue: Calendar.autoupdatingCurrent.firstWeekday)
            ?? .monday
        self.systemFirstWeekday = resolvedFirstWeekday
        reuseCalendar = Self.makeCalendar(
            timeZone: timeZone,
            firstWeekday: resolvedFirstWeekday
        )
    }

    func cells(
        for displayedMonth: CalendarMonthID,
        today: CalendarDayID,
        weekStart: WeekStartOption
    ) throws -> [CalendarCellModel] {
        guard Rule.firstMonth...Rule.lastMonth ~= displayedMonth.month else {
            throw CalendarServiceError.invalidMonth(displayedMonth)
        }

        let firstWeekday = weekStart.resolvedWeekday(
            systemFirstWeekday: systemFirstWeekday
        )
        // 月份网格重建是冷路径（跨天/换月），布局随 weekStart 变化，
        // 与热路径复用的 reuseCalendar 分开构建。
        let calendar = Self.makeCalendar(
            timeZone: timeZone,
            firstWeekday: firstWeekday
        )
        let firstDayID = CalendarDayID(
            year: displayedMonth.year,
            month: displayedMonth.month,
            day: Rule.firstDayOfMonth
        )
        guard let firstDate = date(for: firstDayID, calendar: calendar) else {
            throw CalendarServiceError.invalidMonth(displayedMonth)
        }

        let weekday = calendar.component(.weekday, from: firstDate)
        let leadingDayCount = (
            weekday - firstWeekday.rawValue + Rule.daysPerWeek
        ) % Rule.daysPerWeek
        guard let gridStart = calendar.date(
            byAdding: .day,
            value: -leadingDayCount,
            to: firstDate
        ) else {
            throw CalendarServiceError.dateCalculationFailed
        }

        return try (0..<Rule.gridCellCount).map { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else {
                throw CalendarServiceError.dateCalculationFailed
            }
            let id = dayID(for: date, calendar: calendar)
            return CalendarCellModel(
                id: id,
                isInDisplayedMonth: id.year == displayedMonth.year
                    && id.month == displayedMonth.month,
                isToday: id == today
            )
        }
    }

    func dayID(for date: Date) -> CalendarDayID {
        dayID(for: date, calendar: reuseCalendar)
    }

    func noonDate(for id: CalendarDayID) -> Date? {
        date(for: id, calendar: reuseCalendar)
    }

    func isValid(month: CalendarMonthID) -> Bool {
        Rule.firstMonth...Rule.lastMonth ~= month.month
    }

    func day(
        byAdding offset: Int,
        to day: CalendarDayID
    ) -> CalendarDayID? {
        let calendar = reuseCalendar
        guard
            let date = date(for: day, calendar: calendar),
            let adjustedDate = calendar.date(byAdding: .day, value: offset, to: date)
        else {
            return nil
        }
        return dayID(for: adjustedDate, calendar: calendar)
    }

    func month(
        byAdding offset: Int,
        to displayedMonth: CalendarMonthID
    ) -> CalendarMonthID? {
        guard isValid(month: displayedMonth) else {
            return nil
        }
        let calendar = reuseCalendar
        let firstDay = CalendarDayID(
            year: displayedMonth.year,
            month: displayedMonth.month,
            day: Rule.firstDayOfMonth
        )
        guard
            let date = date(for: firstDay, calendar: calendar),
            let adjustedDate = calendar.date(byAdding: .month, value: offset, to: date)
        else {
            return nil
        }
        let components = calendar.dateComponents([.year, .month], from: adjustedDate)
        guard let year = components.year, let month = components.month else {
            return nil
        }
        return CalendarMonthID(year: year, month: month)
    }

    private static func makeCalendar(
        timeZone: TimeZone,
        firstWeekday: CalendarWeekday
    ) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = firstWeekday.rawValue
        return calendar
    }

    private func date(for id: CalendarDayID, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = timeZone
        components.year = id.year
        components.month = id.month
        components.day = id.day
        components.hour = Rule.noonHour
        guard let date = calendar.date(from: components) else {
            return nil
        }
        return dayID(for: date, calendar: calendar) == id ? date : nil
    }

    private func dayID(for date: Date, calendar: Calendar) -> CalendarDayID {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return CalendarDayID(
            year: components.year ?? .zero,
            month: components.month ?? .zero,
            day: components.day ?? .zero
        )
    }
}
