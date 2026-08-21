//
//  TymeLunarAdapter.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Tyme4Swift

/// 全项目唯一允许 import Tyme4Swift 的文件（设计 7.2/9）。
/// Tyme 对象在本文件内创建并消费，返回值均为 Sendable 应用模型，
/// 不让第三方类型跨 actor 边界。
nonisolated struct TymeLunarAdapter: Sendable {
    private enum Rule {
        // Tyme4Swift 的 LunarDay.NAMES 是 static var，严格并发下不可直接引用；
        // 初一的日名固定为“初一”，金样例测试会锁住该约定。
        static let firstDayOfMonthName = "初一"
    }

    /// 库抛出异常或超出支持范围时返回 nil，调用方显示“农历不可用”。
    func information(for day: CalendarDayID) -> LunarDayInformation? {
        guard let solarDay = try? SolarDay.fromYmd(day.year, day.month, day.day) else {
            return nil
        }

        let lunarDay = solarDay.getLunarDay()
        let lunarMonth = lunarDay.lunarMonth
        let monthName = lunarMonth.getName()
        let dayName = lunarDay.getName()

        let solarTermName: String?
        if solarDay.termDay.dayIndex == 0 {
            solarTermName = solarDay.termDay.solarTerm.getName()
        } else {
            solarTermName = nil
        }

        let festivalBadge: LunarDayBadge? = lunarDay.festival
            .map { .lunarFestival($0.getName()) }
        let monthStartBadge: LunarDayBadge = dayName == Rule.firstDayOfMonthName
            ? .lunarDay(monthName)
            : .lunarDay(dayName)

        // 完整优先级：节气 > 农历节日 > 农历日期；
        // 关闭节气显示时降级为：农历节日 > 农历日期（初一显示月名）。
        let badgeWithoutSolarTerm = festivalBadge ?? monthStartBadge
        let badge: LunarDayBadge
        if let solarTermName {
            badge = .solarTerm(solarTermName)
        } else {
            badge = badgeWithoutSolarTerm
        }

        let nextTerm = solarDay.term.next(1)
        let daysRemaining = nextTerm.getSolarDay().subtract(solarDay)

        return LunarDayInformation(
            badge: badge,
            badgeWithoutSolarTerm: badgeWithoutSolarTerm,
            fullDate: "\(lunarMonth.lunarYear.sixtyCycle)年\(monthName)\(dayName)",
            solarTermName: solarTermName,
            nextSolarTerm: SolarTermCountdown(
                name: nextTerm.getName(),
                daysRemaining: daysRemaining
            )
        )
    }
}
