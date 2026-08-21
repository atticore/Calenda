//
//  Settings.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

nonisolated enum MenuBarStyle: String, Sendable, Equatable {
    case icon
    case iconAndDate
}

nonisolated enum TemperatureUnit: String, Sendable, Equatable {
    case celsius
    case fahrenheit
}

/// 手动城市的稳定保存字段（设计 11.3）；显示名称由结构化字段拼接。
nonisolated struct ManualCity: Codable, Sendable, Equatable, Hashable {
    let name: String
    let admin1: String
    let countryCode: String
    let latitude: Double
    let longitude: Double
    let timezone: String

    var hasValidCoordinates: Bool {
        (-90.0...90.0).contains(latitude) && (-180.0...180.0).contains(longitude)
    }
}

/// 位置选择来源（设计 11.1/15.3）。
/// 运行时的“定位不可用”属于权限状态，由 Phase 3 的 AppModel 表达，
/// 不作为持久化设置值。
nonisolated enum LocationSelection: Sendable, Equatable {
    case defaultCity
    case manual(ManualCity)
    case currentLocation
}

nonisolated struct AppSettings: Sendable, Equatable {
    var weekStart: WeekStartOption
    var showsLunar: Bool
    var showsSolarTerms: Bool
    var showsChineseHolidays: Bool
    var menuBarStyle: MenuBarStyle
    var isWeatherEnabled: Bool
    var activeLocation: LocationSelection
    /// 最近一次选中的手动城市（设计 11.3）：与 activeLocation
    /// 分开保存，城市来源切回“手动”时无需重新搜索。
    var lastManualLocation: ManualCity?
    var temperatureUnit: TemperatureUnit
}

extension AppSettings {
    /// 设计 15.2 的默认值：周一、全部显示项开启、图标加日期、
    /// 天气开启、默认城市（北京）、摄氏度、尚无手动城市。
    static let defaultSettings = AppSettings(
        weekStart: .monday,
        showsLunar: true,
        showsSolarTerms: true,
        showsChineseHolidays: true,
        menuBarStyle: .iconAndDate,
        isWeatherEnabled: true,
        activeLocation: .defaultCity,
        lastManualLocation: nil,
        temperatureUnit: .celsius
    )
}
