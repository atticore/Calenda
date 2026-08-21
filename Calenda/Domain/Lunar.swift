//
//  Lunar.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

/// 日格第二行的语义徽标，优先级：节气 > 农历节日 > 农历日期。
/// 法定节日徽标由 Phase 2 的 HolidayService 提供，不在此建模。
nonisolated enum LunarDayBadge: Sendable, Equatable {
    case solarTerm(String)
    case lunarFestival(String)
    case lunarDay(String)

    /// 徽标携带的展示文案。
    var label: String {
        switch self {
        case let .solarTerm(label), let .lunarFestival(label), let .lunarDay(label):
            return label
        }
    }
}

nonisolated struct SolarTermCountdown: Sendable, Equatable {
    let name: String
    let daysRemaining: Int
}

/// 单个公历日的农历展示信息；由 TymeLunarAdapter 从 Tyme4Swift 换算，
/// 隐藏第三方类型（设计第 9 章）。
nonisolated struct LunarDayInformation: Sendable, Equatable {
    /// 日格第二行文案（完整优先级：节气 > 农历节日 > 农历日期）
    let badge: LunarDayBadge
    /// 关闭节气显示时的降级徽标（农历节日 > 农历日期）
    let badgeWithoutSolarTerm: LunarDayBadge
    /// 完整农历日期，例如“丙午年七月初六”
    let fullDate: String
    /// 当天恰为节气交节日时的节气名，例如“处暑”
    let solarTermName: String?
    /// 距下一个节气的倒计时；节气当天指向再下一个节气
    let nextSolarTerm: SolarTermCountdown
}

nonisolated struct LunarSnapshot: Sendable, Equatable {
    let informationByDay: [CalendarDayID: LunarDayInformation]

    init(informationByDay: [CalendarDayID: LunarDayInformation] = [:]) {
        self.informationByDay = informationByDay
    }

    func information(for day: CalendarDayID) -> LunarDayInformation? {
        informationByDay[day]
    }
}

nonisolated protocol LunarCalendarProviding: Sendable {
    func information(for days: [CalendarDayID]) async -> LunarSnapshot
}
