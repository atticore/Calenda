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
    /// 二级行政区（地级市），同名不同城时用于消歧；
    /// 旧持久化数据可能缺失，解码回退空串。
    var admin2: String = ""
    /// 本地化国家名（如“中国”）；旧持久化数据可能缺失，解码回退空串。
    var country: String = ""
    let countryCode: String
    let latitude: Double
    let longitude: Double
    let timezone: String

    init(
        name: String,
        admin1: String,
        countryCode: String,
        latitude: Double,
        longitude: Double,
        timezone: String,
        admin2: String = "",
        country: String = ""
    ) {
        self.name = name
        self.admin1 = admin1
        self.admin2 = admin2
        self.country = country
        self.countryCode = countryCode
        self.latitude = latitude
        self.longitude = longitude
        self.timezone = timezone
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        admin1 = try container.decode(String.self, forKey: .admin1)
        admin2 = try container.decodeIfPresent(String.self, forKey: .admin2) ?? ""
        country = try container.decodeIfPresent(String.self, forKey: .country) ?? ""
        countryCode = try container.decode(String.self, forKey: .countryCode)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        timezone = try container.decode(String.self, forKey: .timezone)
    }

    var hasValidCoordinates: Bool {
        (-90.0...90.0).contains(latitude) && (-180.0...180.0).contains(longitude)
    }
}

extension ManualCity {
    /// 搜索结果消歧行：一级行政区 · 二级行政区 · 国家（去重、去空）。
    /// 地理编码常有同名小居民点（如云南丽江的“上海”），完整行政
    /// 链避免被读成“上海属于云南”；字段全空时回退时区标识。
    nonisolated var regionDetail: String {
        var parts: [String] = []
        for part in [admin1, admin2, country]
        where !part.isEmpty && !parts.contains(part) {
            parts.append(part)
        }
        return parts.isEmpty
            ? timezone
            : parts.joined(separator: " · ")
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

extension LocationSelection {
    nonisolated var isCurrentLocation: Bool {
        if case .currentLocation = self {
            return true
        }
        return false
    }
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
