//
//  LocationTests.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Foundation
import Testing
@testable import Calenda

// MARK: - 城市搜索模型

@Suite(.serialized)
@MainActor
struct CitySearchModelTests {
    private actor RecordingSearcher: CitySearching {
        private var queries: [String] = []
        private let result: Result<[ManualCity], UserFacingError>

        init(result: Result<[ManualCity], UserFacingError>) {
            self.result = result
        }

        func searchCities(
            matching query: String
        ) async -> Result<[ManualCity], UserFacingError> {
            queries.append(query)
            return result
        }

        var requestedQueries: [String] {
            queries
        }
    }

    private func drainUntil(
        timeout: TimeInterval = 2,
        _ condition: () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            await MainActor.run {
                RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            }
        }
    }

    private let beijing = ManualCity(
        name: "北京",
        admin1: "北京市",
        countryCode: "CN",
        latitude: 39.9042,
        longitude: 116.4074,
        timezone: "Asia/Shanghai"
    )

    @Test
    func shortQueryStaysIdleWithoutSearching() async throws {
        let searcher = RecordingSearcher(result: .success([beijing]))
        let model = CitySearchModel(searcher: searcher)

        model.queryDidChange("北")
        // 超过防抖窗口后仍未发起搜索
        try? await Task.sleep(for: .seconds(0.6))

        #expect(model.phase == .idle)
        #expect(await searcher.requestedQueries.isEmpty)
    }

    @Test
    func debouncedSearchPublishesResults() async throws {
        let searcher = RecordingSearcher(result: .success([beijing]))
        let model = CitySearchModel(searcher: searcher)

        model.queryDidChange("北京")
        #expect(model.phase == .searching)
        await drainUntil {
            if case .results = model.phase { return true }
            return false
        }

        guard case let .results(cities) = model.phase else {
            Issue.record("期望 results，实际：\(model.phase)")
            return
        }
        #expect(cities == [beijing])
        #expect(await searcher.requestedQueries == ["北京"])
    }

    @Test
    func rapidInputCollapsesIntoSingleSearch() async {
        let searcher = RecordingSearcher(result: .success([beijing]))
        let model = CitySearchModel(searcher: searcher)

        model.queryDidChange("北")
        model.queryDidChange("北京")
        model.queryDidChange("北京市")
        await drainUntil {
            if case .results = model.phase { return true }
            return false
        }

        // 防抖内只有最后一次输入发出请求
        #expect(await searcher.requestedQueries.count == 1)
        #expect(await searcher.requestedQueries.first == "北京市")
    }

    @Test
    func emptyResultsShowEmptyPhase() async {
        let searcher = RecordingSearcher(result: .success([]))
        let model = CitySearchModel(searcher: searcher)

        model.queryDidChange("北京")
        await drainUntil { model.phase == .empty }
    }

    @Test
    func searchFailureMapsToFailedPhase() async {
        let searcher = RecordingSearcher(result: .failure(.rateLimited))
        let model = CitySearchModel(searcher: searcher)

        model.queryDidChange("北京")
        await drainUntil { model.phase == .failed(.rateLimited) }
    }

    @Test
    func selectionCommitsThroughCallbackOnly() async {
        let searcher = RecordingSearcher(result: .success([beijing]))
        let model = CitySearchModel(searcher: searcher)
        var selected: ManualCity?
        model.onSelect = { city in
            selected = city
        }

        model.queryDidChange("北京")
        await drainUntil {
            if case .results = model.phase { return true }
            return false
        }
        model.select(beijing)

        #expect(model.phase == .idle)
        #expect(selected == beijing)
    }
}

// MARK: - AppModel 当前位置流程

@MainActor
struct LocationAppModelTests {
    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "CalendaTests.Location.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        UserDefaults().removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func drainUntil(
        timeout: TimeInterval = 2,
        _ condition: () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            await MainActor.run {
                RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            }
        }
    }

    private let suzhou = WeatherLocation(
        displayName: "苏州",
        coordinates: GeoPoint(latitude: 31.30, longitude: 120.62),
        timezone: "Asia/Shanghai",
        isCurrentLocation: true
    )

    @Test
    func currentLocationSelectionResolvesAndFetches() async throws {
        let store = SettingsStore(defaults: try makeDefaults())
        let model = AppModel(
            clock: FixedTestClock(now: ISO8601DateFormatter().date(from: "2026-08-21T10:00:00Z")!),
            calendarService: CalendarService(timeZone: TimeZone(secondsFromGMT: 0)!),
            settings: store,
            weatherService: CannedWeather(mode: .success(temperature: 26)),
            locationService: StubLocating(result: .success(suzhou))
        )
        store.update { $0.activeLocation = .currentLocation }

        model.panelWillAppear()
        await drainUntil {
            if case let .loaded(loaded, _) = model.weatherState {
                return loaded.location == suzhou
            }
            return false
        }

        guard case let .loaded(loaded, _) = model.weatherState else {
            Issue.record("期望 loaded，实际：\(model.weatherState)")
            return
        }
        #expect(loaded.location.isCurrentLocation)
        #expect(loaded.location.displayName == "苏州")
        model.panelDidDisappear()
    }

    @Test
    func deniedLocationFallsBackToDefaultCity() async throws {
        let store = SettingsStore(defaults: try makeDefaults())
        let model = AppModel(
            clock: FixedTestClock(now: ISO8601DateFormatter().date(from: "2026-08-21T10:00:00Z")!),
            calendarService: CalendarService(timeZone: TimeZone(secondsFromGMT: 0)!),
            settings: store,
            weatherService: CannedWeather(mode: .success(temperature: 26)),
            locationService: StubLocating(result: .failure(UserFacingError.locationUnavailable))
        )

        // 先加载默认城市天气，再切当前位置并失败：应回退默认城市并保持可用。
        model.panelWillAppear()
        await drainUntil {
            if case .loaded = model.weatherState { return true }
            return false
        }
        store.update { $0.activeLocation = .currentLocation }
        await drainUntil {
            if case let .loaded(snapshot, _) = model.weatherState {
                return snapshot.location == .defaultCity
                    && store.settings.activeLocation == .defaultCity
            }
            return false
        }

        guard case let .loaded(snapshot, _) = model.weatherState else {
            Issue.record("期望回退后 loaded，实际：\(model.weatherState)")
            return
        }
        #expect(snapshot.location == .defaultCity)
        #expect(store.settings.activeLocation == .defaultCity)
        model.panelDidDisappear()
    }

    @Test
    func lateCurrentLocationResultCannotOverwriteManualCity() async throws {
        let store = SettingsStore(defaults: try makeDefaults())
        let shanghai = ManualCity(
            name: "上海",
            admin1: "上海市",
            countryCode: "CN",
            latitude: 31.23,
            longitude: 121.47,
            timezone: "Asia/Shanghai"
        )
        let model = AppModel(
            clock: FixedTestClock(now: ISO8601DateFormatter().date(from: "2026-08-21T10:00:00Z")!),
            calendarService: CalendarService(timeZone: TimeZone(secondsFromGMT: 0)!),
            settings: store,
            weatherService: CannedWeather(mode: .success(temperature: 30)),
            locationService: DelayedLocating(result: .success(suzhou), delay: 0.4)
        )
        store.update { $0.activeLocation = .currentLocation }

        model.panelWillAppear()
        // 解析未完成时立刻切回手动城市
        store.update { $0.activeLocation = .manual(shanghai) }
        await drainUntil {
            if case let .loaded(loaded, _) = model.weatherState {
                return loaded.location == WeatherLocation(city: shanghai)
            }
            return false
        }
        // 等待迟到的当前位置解析返回后再次确认未被覆盖
        try? await Task.sleep(for: .seconds(0.6))

        guard case let .loaded(finalSnapshot, _) = model.weatherState else {
            Issue.record("期望 loaded，实际：\(model.weatherState)")
            return
        }
        #expect(finalSnapshot.location == WeatherLocation(city: shanghai))
        model.panelDidDisappear()
    }

    @Test
    func useCurrentLocationWritesSelectionThroughSettings() async throws {
        let store = SettingsStore(defaults: try makeDefaults())
        let model = AppModel(
            clock: FixedTestClock(now: ISO8601DateFormatter().date(from: "2026-08-21T10:00:00Z")!),
            calendarService: CalendarService(timeZone: TimeZone(secondsFromGMT: 0)!),
            settings: store,
            weatherService: CannedWeather(mode: .success(temperature: 26)),
            locationService: StubLocating(result: .success(suzhou))
        )

        model.useCurrentLocation()
        #expect(store.settings.activeLocation == .currentLocation)
        model.panelDidDisappear()
    }

    @Test
    func currentLocationIsResolvedOnlyOnceForAWeatherRefresh() async throws {
        let store = SettingsStore(defaults: try makeDefaults())
        let locationService = CountingLocating(location: suzhou)
        let model = AppModel(
            clock: FixedTestClock(now: ISO8601DateFormatter().date(from: "2026-08-21T10:00:00Z")!),
            calendarService: CalendarService(timeZone: TimeZone(secondsFromGMT: 0)!),
            settings: store,
            weatherService: CannedWeather(mode: .success(temperature: 26)),
            locationService: locationService
        )

        model.useCurrentLocation()
        model.panelWillAppear()
        await drainUntil {
            if case let .loaded(snapshot, _) = model.weatherState {
                return snapshot.location == self.suzhou
            }
            return false
        }

        #expect(await locationService.requestCount == LocationRequestExpectation.singleRequest)
        model.panelDidDisappear()
    }

    @Test
    func replacingAnInFlightCurrentLocationRefreshCancelsTheOldRequest() async throws {
        let store = SettingsStore(defaults: try makeDefaults())
        let locationService = CancellationTrackingLocating(location: suzhou)
        let model = AppModel(
            clock: FixedTestClock(now: ISO8601DateFormatter().date(from: "2026-08-21T10:00:00Z")!),
            calendarService: CalendarService(timeZone: TimeZone(secondsFromGMT: 0)!),
            settings: store,
            weatherService: CannedWeather(mode: .success(temperature: 26)),
            locationService: locationService
        )

        model.useCurrentLocation()
        model.panelWillAppear()
        await waitForLocationRequests(locationService, count: 1)

        // 已经选择当前位置时再次点击，必须取消旧请求并由新请求完成刷新。
        model.useCurrentLocation()
        await drainUntil {
            if case let .loaded(snapshot, _) = model.weatherState {
                return snapshot.location == self.suzhou
            }
            return false
        }

        #expect(await locationService.requestCount == LocationRequestExpectation.replacedRequestCount)
        #expect(await locationService.didCancelFirstRequest)
        model.panelDidDisappear()
    }

    private func waitForLocationRequests(
        _ locationService: CancellationTrackingLocating,
        count: Int
    ) async {
        let deadline = Date().addingTimeInterval(LocationRequestExpectation.timeout)
        while await locationService.requestCount < count, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(LocationRequestExpectation.pollIntervalMilliseconds))
        }
    }
}

// MARK: - 定位与天气替身

private enum CannedWeatherMode: Sendable {
    case success(temperature: Double)
    case failure(UserFacingError)
}

private struct CannedWeather: WeatherProviding {
    private let mode: CannedWeatherMode

    init(mode: CannedWeatherMode) {
        self.mode = mode
    }

    func weather(
        for location: WeatherLocation,
        policy: RefreshPolicy
    ) async throws -> WeatherSnapshot {
        switch mode {
        case let .success(temperature):
            return WeatherSnapshot(
                location: location,
                condition: .partlyCloudy,
                temperatureCelsius: temperature,
                apparentTemperatureCelsius: temperature + 2,
                isDay: true,
                observedAt: Date(timeIntervalSince1970: 1_800_000_000),
                fetchedAt: Date(timeIntervalSince1970: 1_800_000_050)
            )
        case let .failure(error):
            throw error
        }
    }
}

private struct FixedTestClock: ClockProviding, Sendable {
    private let date: Date

    init(now date: Date) {
        self.date = date
    }

    var now: Date {
        date
    }
}

// MARK: - 定位替身

private actor StubLocating: Locating {
    private let result: Result<WeatherLocation, any Error>

    init(result: Result<WeatherLocation, any Error>) {
        self.result = result
    }

    func currentLocation() throws -> WeatherLocation {
        switch result {
        case let .success(location):
            return location
        case let .failure(error):
            throw error
        }
    }
}

private actor DelayedLocating: Locating {
    private let result: Result<WeatherLocation, any Error>
    private let delay: TimeInterval

    init(result: Result<WeatherLocation, any Error>, delay: TimeInterval) {
        self.result = result
        self.delay = delay
    }

    func currentLocation() async throws -> WeatherLocation {
        try? await Task.sleep(for: .seconds(delay))
        switch result {
        case let .success(location):
            return location
        case let .failure(error):
            throw error
        }
    }
}

private actor CountingLocating: Locating {
    private let location: WeatherLocation
    private(set) var requestCount = 0

    init(location: WeatherLocation) {
        self.location = location
    }

    func currentLocation() async throws -> WeatherLocation {
        requestCount += 1
        return location
    }
}

private actor CancellationTrackingLocating: Locating {
    private let location: WeatherLocation
    private var firstRequestContinuation: CheckedContinuation<WeatherLocation, any Error>?
    private(set) var requestCount = 0
    private(set) var didCancelFirstRequest = false

    init(location: WeatherLocation) {
        self.location = location
    }

    func currentLocation() async throws -> WeatherLocation {
        requestCount += 1
        guard requestCount == LocationRequestExpectation.singleRequest else {
            return location
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                firstRequestContinuation = continuation
            }
        } onCancel: {
            Task {
                await self.cancelFirstRequest()
            }
        }
    }

    private func cancelFirstRequest() {
        guard let continuation = firstRequestContinuation else {
            return
        }
        firstRequestContinuation = nil
        didCancelFirstRequest = true
        continuation.resume(throwing: CancellationError())
    }
}

private enum LocationRequestExpectation {
    static let singleRequest = 1
    static let replacedRequestCount = 2
    static let timeout: TimeInterval = 2
    static let pollIntervalMilliseconds = 10
}

// MARK: - lastManualLocation 持久化

@Suite(.serialized)
@MainActor
struct LastManualLocationPersistenceTests {
    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "CalendaTests.LastManual.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        UserDefaults().removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test
    func roundTripsManualCity() throws {
        let defaults = try makeDefaults()
        let city = ManualCity(
            name: "苏州",
            admin1: "江苏省",
            countryCode: "CN",
            latitude: 31.30,
            longitude: 120.62,
            timezone: "Asia/Shanghai"
        )

        let store = SettingsStore(defaults: defaults)
        store.update { $0.lastManualLocation = city }
        let reloaded = SettingsStore(defaults: defaults)

        #expect(reloaded.settings.lastManualLocation == city)
        #expect(reloaded.settings.activeLocation == .defaultCity)
    }

    @Test
    func defaultsToNilAndSurvivesCorruptData() throws {
        let defaults = try makeDefaults()
        let store = SettingsStore(defaults: defaults)
        #expect(store.settings.lastManualLocation == nil)

        defaults.set(Data("not-json".utf8), forKey: "settings.lastManualLocation")
        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.settings.lastManualLocation == nil)
        // 其他字段不受影响
        #expect(reloaded.settings.isWeatherEnabled)
    }

    @Test
    func invalidCoordinatesFallBackToNil() throws {
        let defaults = try makeDefaults()
        let invalid = ManualCity(
            name: "无效",
            admin1: "",
            countryCode: "",
            latitude: 200,
            longitude: 999,
            timezone: ""
        )
        defaults.set(
            try JSONEncoder().encode(invalid),
            forKey: "settings.lastManualLocation"
        )

        let store = SettingsStore(defaults: defaults)
        #expect(store.settings.lastManualLocation == nil)
    }
}

// MARK: - 手动城市消歧

@Suite
struct ManualCityRegionTests {
    @Test
    func regionDetailDisambiguatesSameNamePlaces() {
        // 直辖市：一二级同名去重，国家用本地化名
        let metropolis = ManualCity(
            name: "上海",
            admin1: "上海市",
            countryCode: "CN",
            latitude: 31.22222,
            longitude: 121.45806,
            timezone: "Asia/Shanghai",
            admin2: "上海市",
            country: "中国"
        )
        #expect(metropolis.regionDetail == "上海市 · 中国")

        // 同名小居民点：带出二级行政区，避免读作“上海属于云南”
        let village = ManualCity(
            name: "上海",
            admin1: "云南",
            countryCode: "CN",
            latitude: 27.0741,
            longitude: 100.107,
            timezone: "Asia/Shanghai",
            admin2: "丽江市",
            country: "中国"
        )
        #expect(village.regionDetail == "云南 · 丽江市 · 中国")

        // 旧数据缺省字段：本地化国家名缺失时退化为仅一级行政区
        let legacy = ManualCity(
            name: "上海",
            admin1: "上海市",
            countryCode: "CN",
            latitude: 31.22222,
            longitude: 121.45806,
            timezone: "Asia/Shanghai"
        )
        #expect(legacy.regionDetail == "上海市")
    }

    @Test
    func decodesLegacyManualCityWithoutOptionalRegionFields() throws {
        let json = """
        {"name":"上海","admin1":"上海市","countryCode":"CN",
        "latitude":31.2,"longitude":121.4,"timezone":"Asia/Shanghai"}
        """
        let city = try JSONDecoder().decode(
            ManualCity.self,
            from: Data(json.utf8)
        )
        #expect(city.admin2 == "")
        #expect(city.country == "")
        #expect(city.name == "上海")
    }
}
