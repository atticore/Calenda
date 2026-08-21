//
//  TymeLunarAdapterTests.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Foundation
import Testing
@testable import Calenda

/// 金样例基准：依赖升级必须继续通过（设计 9/18.1）。
/// 事实来源：国务院办公厅 2026 年放假安排、新华社闰六月报道、
/// 维基百科冬至条目及 DESIGN.md 5.1 示例。
struct TymeLunarAdapterTests {
    private let adapter = TymeLunarAdapter()

    @Test
    func mapsSpringFestival2026() {
        let information = adapter.information(
            for: CalendarDayID(year: 2026, month: 2, day: 17)
        )
        #expect(information?.badge == .lunarFestival("春节"))
        #expect(information?.fullDate == "丙午年正月初一")
    }

    @Test
    func mapsDragonBoatFestival2026() {
        let information = adapter.information(
            for: CalendarDayID(year: 2026, month: 6, day: 19)
        )
        #expect(information?.badge == .lunarFestival("端午节"))
        #expect(information?.fullDate == "丙午年五月初五")
    }

    @Test
    func mapsMidAutumnFestival2026() {
        let information = adapter.information(
            for: CalendarDayID(year: 2026, month: 9, day: 25)
        )
        #expect(information?.badge == .lunarFestival("中秋节"))
        #expect(information?.fullDate == "丙午年八月十五")
    }

    @Test
    func mapsLeapMonthFirstDay2025() {
        let information = adapter.information(
            for: CalendarDayID(year: 2025, month: 7, day: 25)
        )
        #expect(information?.badge == .lunarDay("闰六月"))
        #expect(information?.fullDate == "乙巳年闰六月初一")
    }

    @Test
    func solarTermOutranksLunarFestivalOnQingming2026() {
        let information = adapter.information(
            for: CalendarDayID(year: 2026, month: 4, day: 5)
        )
        #expect(information?.badge == .solarTerm("清明"))
        #expect(information?.solarTermName == "清明")
    }

    @Test
    func solarTermOutranksFirstDayOfMonthOnChushu2025() {
        let information = adapter.information(
            for: CalendarDayID(year: 2025, month: 8, day: 23)
        )
        #expect(information?.badge == .solarTerm("处暑"))
        #expect(information?.fullDate == "乙巳年七月初一")
    }

    @Test
    func mapsWinterSolstice2026() {
        let information = adapter.information(
            for: CalendarDayID(year: 2026, month: 12, day: 22)
        )
        #expect(information?.badge == .solarTerm("冬至"))
        #expect(information?.fullDate == "丙午年十一月十四")
    }

    @Test
    func countsDownToNextSolarTerm() {
        let information = adapter.information(
            for: CalendarDayID(year: 2026, month: 8, day: 18)
        )
        #expect(information?.nextSolarTerm.name == "处暑")
        #expect(information?.nextSolarTerm.daysRemaining == 5)
    }

    @Test
    func returnsNilForUnsupportedDates() {
        let information = adapter.information(
            for: CalendarDayID(year: 0, month: 1, day: 1)
        )
        #expect(information == nil)
    }
}

struct LunarServiceTests {
    @Test
    func batchesAWholeMonthGridAndStaysConsistent() async {
        let service = LunarService()
        let calendar = CalendarService(timeZone: TimeZone(identifier: "Asia/Shanghai")!)
        let cells = try! calendar.cells(
            for: CalendarMonthID(year: 2026, month: 2),
            today: CalendarDayID(year: 2026, month: 2, day: 14),
            weekStart: .monday
        )
        let days = cells.map(\.id)

        let first = await service.information(for: days)
        let second = await service.information(for: days)

        #expect(first.informationByDay.count == 42)
        #expect(first == second)
    }
}
