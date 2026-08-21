//
//  SettingsStoreTests.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Foundation
import Testing
@testable import Calenda

@MainActor
struct SettingsStoreTests {
    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "CalendaTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        UserDefaults().removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test
    func startsFromDefaultsOnAFreshSuite() {
        let store = SettingsStore(defaults: makeIsolatedDefaults())

        #expect(store.settings == .defaultSettings)
    }

    @Test
    func updatePersistsAndPublishesAtomically() {
        let defaults = makeIsolatedDefaults()
        let store = SettingsStore(defaults: defaults)

        store.update { $0.weekStart = .sunday }
        store.update { $0.temperatureUnit = .fahrenheit }

        #expect(store.settings.weekStart == .sunday)
        #expect(store.settings.temperatureUnit == .fahrenheit)

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.settings.weekStart == .sunday)
        #expect(reloaded.settings.temperatureUnit == .fahrenheit)
    }

    @Test
    func unknownEnumRawValuesFallBackToSafeDefaults() {
        let defaults = makeIsolatedDefaults()
        defaults.set("friday", forKey: "settings.weekStart")
        defaults.set("round", forKey: "settings.menuBarStyle")
        defaults.set("kelvin", forKey: "settings.temperatureUnit")

        let store = SettingsStore(defaults: defaults)

        #expect(
            store.settings.weekStart == AppSettings.defaultSettings.weekStart
        )
        #expect(
            store.settings.menuBarStyle
                == AppSettings.defaultSettings.menuBarStyle
        )
        #expect(
            store.settings.temperatureUnit
                == AppSettings.defaultSettings.temperatureUnit
        )
    }

    @Test
    func corruptedLocationDataFallsBackToDefaultCity() {
        let defaults = makeIsolatedDefaults()
        defaults.set(Data([0xFF, 0xFE]), forKey: "settings.activeLocation")

        let store = SettingsStore(defaults: defaults)

        #expect(store.settings.activeLocation == .defaultCity)
    }

    @Test
    func invalidCoordinatesFallBackToDefaultCity() {
        let defaults = makeIsolatedDefaults()
        let city = ManualCity(
            name: "测试",
            admin1: "测试",
            countryCode: "CN",
            latitude: 200,
            longitude: 0,
            timezone: "Asia/Shanghai"
        )
        let payload = try! JSONEncoder().encode(
            PersistedForTesting.manual(city)
        )
        defaults.set(payload, forKey: "settings.activeLocation")

        let store = SettingsStore(defaults: defaults)

        #expect(store.settings.activeLocation == .defaultCity)
    }

    @Test
    func manualCityRoundTripsThroughPersistence() {
        let defaults = makeIsolatedDefaults()
        let city = ManualCity(
            name: "上海",
            admin1: "上海市",
            countryCode: "CN",
            latitude: 31.23,
            longitude: 121.47,
            timezone: "Asia/Shanghai"
        )
        let store = SettingsStore(defaults: defaults)
        store.update { $0.activeLocation = .manual(city) }

        let reloaded = SettingsStore(defaults: defaults)

        #expect(reloaded.settings.activeLocation == .manual(city))
    }

    @Test
    func migrationIsIdempotent() {
        let defaults = makeIsolatedDefaults()
        defaults.set(0, forKey: "settings.schemaVersion")

        SettingsMigration.migrateIfNeeded(in: defaults)
        let first = defaults.object(forKey: "settings.schemaVersion") as? Int

        SettingsMigration.migrateIfNeeded(in: defaults)
        let second = defaults.object(forKey: "settings.schemaVersion") as? Int

        #expect(first == SettingsMigration.currentSchemaVersion)
        #expect(second == SettingsMigration.currentSchemaVersion)
    }

    @Test
    func storeDoesNotTouchTheStandardSuiteWhenInjected() {
        let defaults = makeIsolatedDefaults()
        let store = SettingsStore(defaults: defaults)
        store.update { $0.showsLunar = false }

        #expect(
            UserDefaults.standard.object(forKey: "settings.showsLunar")
                == nil
        )
    }
}

/// 测试内复刻私有持久化枚举的编码格式，驱动损坏/无效数据用例。
private enum PersistedForTesting: Codable {
    case defaultCity
    case manual(ManualCity)
    case currentLocation
}
