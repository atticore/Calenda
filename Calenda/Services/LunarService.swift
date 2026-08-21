//
//  LunarService.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

/// 串行隔离 Tyme4Swift 计算并缓存结果（设计 7.1/9）。
/// 缓存以 CalendarDayID 为键，农历换算是纯日期函数，
/// 不依赖时区，因此系统时区变化时无需清空。
actor LunarService: LunarCalendarProviding {
    private let adapter = TymeLunarAdapter()
    private var cache: [CalendarDayID: LunarDayInformation] = [:]

    func information(for days: [CalendarDayID]) async -> LunarSnapshot {
        var informationByDay: [CalendarDayID: LunarDayInformation] = [:]
        for day in Set(days) {
            guard let information = cache[day] ?? adapter.information(for: day) else {
                continue
            }
            cache[day] = information
            informationByDay[day] = information
        }
        return LunarSnapshot(informationByDay: informationByDay)
    }
}
