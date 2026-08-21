//
//  SettingsStore.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Foundation
import Observation

extension Notification.Name {
    /// SettingsStore 在一次事务提交后于主线程发送；
    /// 观察方（AppModel、StatusItemController 等）据此即时生效。
    static let appSettingsDidChange = Notification.Name(
        "CalendaAppSettingsDidChange"
    )
}

@MainActor
protocol SettingsProviding: AnyObject {
    var settings: AppSettings { get }
    func update(_ mutation: (inout AppSettings) -> Void)
}

/// 设置的唯一事实源（设计 7.1/14/15.3）：类型化读写、逐字段未知值
/// 回退安全默认、单次主线程事务发布；View 不直接散布 UserDefaults 键。
@MainActor
@Observable
final class SettingsStore: SettingsProviding {
    private enum Keys {
        static let prefix = "settings"
        static let schemaVersion = "\(prefix).schemaVersion"
        static let weekStart = "\(prefix).weekStart"
        static let showsLunar = "\(prefix).showsLunar"
        static let showsSolarTerms = "\(prefix).showsSolarTerms"
        static let showsChineseHolidays = "\(prefix).showsChineseHolidays"
        static let menuBarStyle = "\(prefix).menuBarStyle"
        static let isWeatherEnabled = "\(prefix).isWeatherEnabled"
        static let activeLocation = "\(prefix).activeLocation"
        static let temperatureUnit = "\(prefix).temperatureUnit"
    }

    private let defaults: UserDefaults
    private(set) var settings: AppSettings

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        settings = Self.load(from: defaults)
    }

    func update(_ mutation: (inout AppSettings) -> Void) {
        var next = settings
        mutation(&next)
        Self.persist(next, to: defaults)
        settings = next
        NotificationCenter.default.post(
            name: .appSettingsDidChange,
            object: nil
        )
    }

    // MARK: - 持久化

    private static func load(from defaults: UserDefaults) -> AppSettings {
        SettingsMigration.migrateIfNeeded(in: defaults)

        var loaded = AppSettings.defaultSettings
        loaded.weekStart = defaults.string(forKey: Keys.weekStart)
            .flatMap(WeekStartOption.init(rawValue:))
            ?? loaded.weekStart
        loaded.showsLunar = defaults.object(forKey: Keys.showsLunar)
            as? Bool ?? loaded.showsLunar
        loaded.showsSolarTerms = defaults.object(forKey: Keys.showsSolarTerms)
            as? Bool ?? loaded.showsSolarTerms
        loaded.showsChineseHolidays = defaults.object(
            forKey: Keys.showsChineseHolidays
        ) as? Bool ?? loaded.showsChineseHolidays
        loaded.menuBarStyle = defaults.string(forKey: Keys.menuBarStyle)
            .flatMap(MenuBarStyle.init(rawValue:))
            ?? loaded.menuBarStyle
        loaded.isWeatherEnabled = defaults.object(forKey: Keys.isWeatherEnabled)
            as? Bool ?? loaded.isWeatherEnabled
        loaded.activeLocation = loadActiveLocation(
            from: defaults,
            fallback: loaded.activeLocation
        )
        loaded.temperatureUnit = defaults.string(forKey: Keys.temperatureUnit)
            .flatMap(TemperatureUnit.init(rawValue:))
            ?? loaded.temperatureUnit
        return loaded
    }

    private static func loadActiveLocation(
        from defaults: UserDefaults,
        fallback: LocationSelection
    ) -> LocationSelection {
        guard let data = defaults.data(forKey: Keys.activeLocation) else {
            return fallback
        }
        guard
            let selection = try? JSONDecoder().decode(
                PersistedLocationSelection.self,
                from: data
            )
        else {
            return fallback
        }
        switch selection {
        case .defaultCity:
            return .defaultCity
        case .currentLocation:
            return .currentLocation
        case let .manual(city) where city.hasValidCoordinates:
            return .manual(city)
        default:
            // 无效坐标或损坏字段回退安全默认（设计 14）
            return fallback
        }
    }

    private static func persist(_ settings: AppSettings, to defaults: UserDefaults) {
        defaults.set(
            settings.weekStart.rawValue,
            forKey: Keys.weekStart
        )
        defaults.set(settings.showsLunar, forKey: Keys.showsLunar)
        defaults.set(settings.showsSolarTerms, forKey: Keys.showsSolarTerms)
        defaults.set(
            settings.showsChineseHolidays,
            forKey: Keys.showsChineseHolidays
        )
        defaults.set(settings.menuBarStyle.rawValue, forKey: Keys.menuBarStyle)
        defaults.set(
            settings.isWeatherEnabled,
            forKey: Keys.isWeatherEnabled
        )
        defaults.set(
            settings.activeLocation.persistedData,
            forKey: Keys.activeLocation
        )
        defaults.set(
            settings.temperatureUnit.rawValue,
            forKey: Keys.temperatureUnit
        )
    }
}

/// LocationSelection 带关联值，不能直接以 rawValue 持久化，
/// 统一编码为 JSON 以保证一次写入即一个完整状态。
private extension LocationSelection {
    var persistedData: Data {
        let persisted: PersistedLocationSelection
        switch self {
        case .defaultCity:
            persisted = .defaultCity
        case let .manual(city):
            persisted = .manual(city)
        case .currentLocation:
            persisted = .currentLocation
        }
        // 纯值类型的编码不会失败；万一失败写入空数据，
        // 下次加载会走未知值回退，不破坏安全默认。
        return (try? JSONEncoder().encode(persisted)) ?? Data()
    }
}

/// 持久化用的镜像枚举：关联值必须 Codable，避免 LocationSelection
/// 自身对 Foundation Codable 产生类型耦合。
private enum PersistedLocationSelection: Codable {
    case defaultCity
    case manual(ManualCity)
    case currentLocation
}
