//
//  DayBadge.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

/// 日格第二行的最终展示徽标（设计 8.3）：
/// 法定节日 > 节气 > 农历节日 > 农历日期，
/// 由 AppModel 依据各数据源与显示开关合成。
nonisolated enum DayBadge: Sendable, Equatable {
    case holiday(String)
    case solarTerm(String)
    case lunarFestival(String)
    case lunarDay(String)

    var label: String {
        switch self {
        case let .holiday(label), let .solarTerm(label),
            let .lunarFestival(label), let .lunarDay(label):
            return label
        }
    }
}
