//
//  Weather.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Foundation

/// 稳定的用户可见错误（设计 13.3）：不直接暴露 NSError
/// 或服务端原始文本。
nonisolated enum UserFacingError: Error, Sendable, Equatable {
    case offline
    case timeout
    case rateLimited
    case serverError
    case invalidResponse
    case locationUnavailable
}

nonisolated enum DataFreshness: Sendable, Equatable {
    case fresh
    case stale(updatedAt: Date)
    case bundled
}

nonisolated enum Loadable<Value: Sendable>: Sendable {
    case idle
    case loading(previous: Value?)
    case loaded(Value, freshness: DataFreshness)
    case failed(previous: Value?, error: UserFacingError)
}

extension Loadable: Equatable where Value: Equatable {}

/// 城市级坐标（设计 11.2）：传输前按 0.01° 归一化，
/// 避免发送超出城市天气所需的精确位置。
nonisolated struct GeoPoint: Sendable, Equatable, Codable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = (latitude * 100).rounded() / 100
        self.longitude = (longitude * 100).rounded() / 100
    }
}

/// 天气查询的城市定位；location 内聚在快照类型内，
/// 从类型层面杜绝新城市名称搭配旧城市天气（设计 12.1）。
nonisolated struct WeatherLocation: Sendable, Equatable, Codable {
    let displayName: String
    let coordinates: GeoPoint
    let timezone: String?
    let isDefaultCity: Bool
    let isCurrentLocation: Bool

    /// 默认城市：北京市（设计 1.1/11.3）
    static let defaultCity = WeatherLocation(
        displayName: "北京市",
        coordinates: GeoPoint(latitude: 39.9042, longitude: 116.4074),
        timezone: "Asia/Shanghai",
        isDefaultCity: true,
        isCurrentLocation: false
    )

    init(
        displayName: String,
        coordinates: GeoPoint,
        timezone: String?,
        isDefaultCity: Bool = false,
        isCurrentLocation: Bool = false
    ) {
        self.displayName = displayName
        self.coordinates = coordinates
        self.timezone = timezone
        self.isDefaultCity = isDefaultCity
        self.isCurrentLocation = isCurrentLocation
    }

    /// 手动城市的显示名称由结构化字段拼接（设计 11.3）；
    /// 直辖市（name "上海"、admin1 "上海市"）只显示一级名称。
    init(city: ManualCity) {
        let adminIsRedundant = city.admin1.isEmpty
            || city.admin1 == city.name
            || city.admin1.hasPrefix(city.name)
        let name = adminIsRedundant
            ? city.name
            : "\(city.name)·\(city.admin1)"
        self.init(
            displayName: name,
            coordinates: GeoPoint(
                latitude: city.latitude,
                longitude: city.longitude
            ),
            timezone: city.timezone,
            isDefaultCity: false,
            isCurrentLocation: false
        )
    }

    /// 由持久化的位置选择解析查询城市；当前位置由定位服务解析，
    /// 失败时由上层天气流程回退默认城市。
    static func resolving(_ selection: LocationSelection) -> WeatherLocation? {
        switch selection {
        case .defaultCity:
            return .defaultCity
        case let .manual(city):
            return WeatherLocation(city: city)
        case .currentLocation:
            return nil
        }
    }
}

/// WMO weather code 映射（设计 12.2）；未识别的新代码
/// 映射为 unknown，不因上游新增枚举而解码失败。
nonisolated enum WeatherCondition: Int, Sendable, Equatable, Codable {
    case clearSky = 0
    case mainlyClear = 1
    case partlyCloudy = 2
    case overcast = 3
    case fog = 45
    case rimeFog = 48
    case lightDrizzle = 51
    case drizzle = 53
    case heavyDrizzle = 55
    case lightFreezingDrizzle = 56
    case freezingDrizzle = 57
    case lightRain = 61
    case rain = 63
    case heavyRain = 65
    case lightFreezingRain = 66
    case freezingRain = 67
    case lightSnowfall = 71
    case snowfall = 73
    case heavySnowfall = 75
    case snowGrains = 77
    case lightRainShowers = 80
    case rainShowers = 81
    case heavyRainShowers = 82
    case lightSnowShowers = 85
    case heavySnowShowers = 86
    case thunderstorm = 95
    case thunderstormWithLightHail = 96
    case thunderstormWithHeavyHail = 99
    case unknown = -1

    init(wmoCode: Int) {
        self = Self(rawValue: wmoCode) ?? .unknown
    }
}

nonisolated struct WeatherSnapshot: Sendable, Equatable, Codable {
    let location: WeatherLocation
    let condition: WeatherCondition
    let temperatureCelsius: Double
    let apparentTemperatureCelsius: Double
    let isDay: Bool
    let observedAt: Date
    let fetchedAt: Date
}

// MARK: - 缓存策略与协议

/// 新鲜期 30 分钟、过期但可用期 6 小时（设计 12.3）。
nonisolated enum WeatherCachePolicy {
    static let freshInterval: TimeInterval = 30 * 60
    static let usableInterval: TimeInterval = 6 * 60 * 60

    static func freshness(
        of snapshot: WeatherSnapshot,
        at now: Date
    ) -> DataFreshness {
        let age = now.timeIntervalSince(snapshot.fetchedAt)
        return age <= freshInterval
            ? .fresh
            : .stale(updatedAt: snapshot.fetchedAt)
    }

    static func isUsable(
        _ snapshot: WeatherSnapshot,
        at now: Date
    ) -> Bool {
        now.timeIntervalSince(snapshot.fetchedAt) <= usableInterval
    }
}

nonisolated protocol WeatherProviding: Sendable {
    /// 返回可用的天气快照（缓存或新数据）；完全无可用数据时抛出
    /// UserFacingError。新鲜度由调用方按 fetchedAt 计算。
    func weather(
        for location: WeatherLocation,
        policy: RefreshPolicy
    ) async throws -> WeatherSnapshot
}
