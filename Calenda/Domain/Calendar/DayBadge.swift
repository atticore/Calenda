//
//  DayBadge.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

/// 日格第二行的最终展示徽标（设计 5.4/8.3）：
/// 节气 > 农历节日 > 公历法定节日 > 农历日期，
/// 由 AppModel 依据各数据源与显示开关合成。
/// 法定作息（休/班）由 HolidayMark 单独驱动右上角徽标，
/// 连续假期中间日不重复节日名——假期是“块”，节日名只在锚点日出现。
nonisolated enum DayBadge: Sendable, Equatable {
    case solarTerm(String)
    case lunarFestival(String)
    case solarFestival(String)
    case lunarDay(String)

    var label: String {
        switch self {
        case let .solarTerm(label), let .lunarFestival(label),
            let .solarFestival(label), let .lunarDay(label):
            return label
        }
    }
}
