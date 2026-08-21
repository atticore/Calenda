//
//  WeatherTests.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Foundation
import Testing
@testable import Calenda

// MARK: - 域模型

struct WeatherDomainTests {
    @Test
    func mapsKnownWmoCodes() {
        #expect(WeatherCondition(wmoCode: 0) == .clearSky)
        #expect(WeatherCondition(wmoCode: 3) == .overcast)
        #expect(WeatherCondition(wmoCode: 61) == .lightRain)
        #expect(WeatherCondition(wmoCode: 95) == .thunderstorm)
        #expect(WeatherCondition(wmoCode: 99) == .thunderstormWithHeavyHail)
    }

    @Test
    func unknownCodeMapsToUnknown() {
        #expect(WeatherCondition(wmoCode: 42) == .unknown)
        #expect(WeatherCondition(wmoCode: -5) == .unknown)
    }

    @Test
    func freshnessTransitions() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func snapshot(age: TimeInterval) -> WeatherSnapshot {
            WeatherSnapshot(
                location: .defaultCity,
                condition: .clearSky,
                temperatureCelsius: 25,
                apparentTemperatureCelsius: 26,
                isDay: true,
                observedAt: now,
                fetchedAt: now.addingTimeInterval(-age)
            )
        }

        #expect(
            WeatherCachePolicy.freshness(of: snapshot(age: 60), at: now)
                == .fresh
        )
        #expect(
            WeatherCachePolicy.freshness(of: snapshot(age: 45 * 60), at: now)
                == .stale(updatedAt: snapshot(age: 45 * 60).fetchedAt)
        )
        #expect(WeatherCachePolicy.isUsable(snapshot(age: 60), at: now))
        #expect(WeatherCachePolicy.isUsable(snapshot(age: 3 * 3600), at: now))
        #expect(
            !WeatherCachePolicy.isUsable(snapshot(age: 7 * 3600), at: now)
        )
    }

    @Test
    func temperatureConversionIsLocal() {
        #expect(
            TemperatureFormatter.display(celsius: 0, unit: .celsius) == "0°C"
        )
        #expect(
            TemperatureFormatter.display(celsius: 0, unit: .fahrenheit)
                == "32°F"
        )
        #expect(
            TemperatureFormatter.display(celsius: 100, unit: .fahrenheit)
                == "212°F"
        )
        #expect(
            TemperatureFormatter.display(celsius: 29, unit: .fahrenheit)
                == "84°F"
        )
    }

    @Test
    func geoPointNormalizesToCityScale() {
        let point = GeoPoint(latitude: 39.90429, longitude: 116.40749)
        #expect(point.latitude == 39.90)
        #expect(point.longitude == 116.41)
    }

    @Test
    func locationDisplayNameComposes() {
        let suzhou = ManualCity(
            name: "苏州",
            admin1: "江苏省",
            countryCode: "CN",
            latitude: 31.3,
            longitude: 120.6,
            timezone: "Asia/Shanghai"
        )
        let shanghai = ManualCity(
            name: "上海",
            admin1: "上海市",
            countryCode: "CN",
            latitude: 31.23,
            longitude: 121.47,
            timezone: "Asia/Shanghai"
        )
        #expect(WeatherLocation(city: suzhou).displayName == "苏州·江苏省")
        #expect(WeatherLocation(city: shanghai).displayName == "上海")
        #expect(WeatherLocation.defaultCity.isDefaultCity)
        #expect(WeatherLocation.defaultCity.displayName == "北京市")
    }
}

// MARK: - 缓存

struct WeatherCacheStoreTests {
    @Test
    func roundTripsSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = WeatherCacheStore(directoryURL: directory)
        let snapshot = WeatherSnapshot(
            location: .defaultCity,
            condition: .partlyCloudy,
            temperatureCelsius: 29.3,
            apparentTemperatureCelsius: 31,
            isDay: true,
            observedAt: Date(timeIntervalSince1970: 1_800_000_000),
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_100)
        )

        try store.write(snapshot)

        #expect(store.load() == snapshot)
    }

    @Test
    func missingFileLoadsNil() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = WeatherCacheStore(directoryURL: directory)

        #expect(store.load() == nil)
    }
}

// MARK: - 客户端（URLProtocol 注入）

/// 独立于 HolidayStubProtocol 的静态状态：两个测试套件即使
/// 并发执行也互不污染（各自 .serialized 只串行化自身套件）。
final class WeatherStubProtocol: URLProtocol {
    private struct Stub {
        let status: Int
        let data: Data
    }

    private static let lock = NSLock()
    // nonisolated(unsafe)：访问始终经由 lock，串行化由测试套件
    // 的 .serialized 进一步保证。
    private nonisolated(unsafe) static var stubsByHost: [String: Stub] = [:]
    private nonisolated(unsafe) static var lastRequestedURLString: String?

    static func stub(
        host: String,
        status: Int,
        data: Data = Data()
    ) {
        lock.withLock {
            stubsByHost[host] = Stub(status: status, data: data)
        }
    }

    static func reset() {
        lock.withLock {
            stubsByHost = [:]
            lastRequestedURLString = nil
        }
    }

    static var lastRequestedURL: String? {
        lock.withLock { lastRequestedURLString }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, let host = url.host else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.badURL)
            )
            return
        }
        Self.lock.withLock {
            Self.lastRequestedURLString = url.absoluteString
        }
        let stub = Self.lock.withLock { Self.stubsByHost[host] }
        guard let stub else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.cannotFindHost)
            )
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: stub.status,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite(.serialized)
struct OpenMeteoClientTests {
    private func makeClient(
        now: Date = Date(timeIntervalSince1970: 1_800_000_000)
    ) -> OpenMeteoClient {
        OpenMeteoClient(
            protocolClasses: [WeatherStubProtocol.self],
            nowProvider: { now }
        )
    }

    private func setUp() {
        WeatherStubProtocol.reset()
    }

    @Test
    func decodesForecastWithCityOffset() async {
        setUp()
        WeatherStubProtocol.stub(
            host: "api.open-meteo.com",
            status: 200,
            data: Data(
                """
                {"current":{"time":"2026-08-21T12:30","temperature_2m":29.3,
                "apparent_temperature":31.0,"weather_code":0,"is_day":1},
                "utc_offset_seconds":28800}
                """.utf8
            )
        )

        let outcome = await makeClient().currentWeather(for: .defaultCity)

        guard case let .snapshot(snapshot) = outcome else {
            Issue.record("期望快照，实际：\(outcome)")
            return
        }
        #expect(snapshot.condition == .clearSky)
        #expect(snapshot.isDay)
        #expect(snapshot.temperatureCelsius == 29.3)
        #expect(snapshot.apparentTemperatureCelsius == 31.0)
        #expect(snapshot.location == .defaultCity)
        // 城市本地 12:30（UTC+8）对应 04:30Z
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        #expect(utcCalendar.component(.hour, from: snapshot.observedAt) == 4)
        #expect(utcCalendar.component(.minute, from: snapshot.observedAt) == 30)
    }

    @Test
    func unknownWeatherCodeStillDecodes() async {
        setUp()
        WeatherStubProtocol.stub(
            host: "api.open-meteo.com",
            status: 200,
            data: Data(
                """
                {"current":{"time":"2026-08-21T12:30","temperature_2m":10,
                "apparent_temperature":9,"weather_code":42,"is_day":0},
                "utc_offset_seconds":0}
                """.utf8
            )
        )

        let outcome = await makeClient().currentWeather(for: .defaultCity)

        guard case let .snapshot(snapshot) = outcome else {
            Issue.record("未知天气码不应导致解码失败：\(outcome)")
            return
        }
        #expect(snapshot.condition == .unknown)
        #expect(!snapshot.isDay)
    }

    @Test
    func missingCurrentFieldFails() async {
        setUp()
        WeatherStubProtocol.stub(
            host: "api.open-meteo.com",
            status: 200,
            data: Data("{\"utc_offset_seconds\":0}".utf8)
        )

        let outcome = await makeClient().currentWeather(for: .defaultCity)

        #expect(outcome == .failure(.invalidResponse))
    }

    @Test
    func maps429ToRateLimited() async {
        setUp()
        WeatherStubProtocol.stub(host: "api.open-meteo.com", status: 429)

        let outcome = await makeClient().currentWeather(for: .defaultCity)

        #expect(outcome == .failure(.rateLimited))
    }

    @Test
    func maps5xxToServerError() async {
        setUp()
        WeatherStubProtocol.stub(host: "api.open-meteo.com", status: 503)

        let outcome = await makeClient().currentWeather(for: .defaultCity)

        #expect(outcome == .failure(.serverError))
    }

    @Test
    func geocodingSearchDecodesAndUsesExplicitParameters() async {
        setUp()
        WeatherStubProtocol.stub(
            host: "geocoding-api.open-meteo.com",
            status: 200,
            data: Data(
                """
                {"results":[{"name":"北京","admin1":"北京市",
                "country_code":"CN","latitude":39.9042,"longitude":116.4074,
                "timezone":"Asia/Shanghai"}]}
                """.utf8
            )
        )

        let result = await makeClient().searchCities(matching: "北京")

        guard case let .success(cities) = result else {
            Issue.record("期望城市结果：\(result)")
            return
        }
        #expect(cities.count == 1)
        #expect(cities.first?.name == "北京")
        #expect(cities.first?.countryCode == "CN")

        let requestedURL = WeatherStubProtocol.lastRequestedURL
        #expect(requestedURL?.contains("language=zh") == true)
        #expect(requestedURL?.contains("count=10") == true)
        #expect(requestedURL?.contains("format=json") == true)
    }
}

// MARK: - 服务

private actor RecordingWeatherClient: WeatherFetching {
    private let outcome: WeatherFetchOutcome
    private(set) var requestCount = 0

    init(outcome: WeatherFetchOutcome) {
        self.outcome = outcome
    }

    func currentWeather(
        for location: WeatherLocation
    ) async -> WeatherFetchOutcome {
        requestCount += 1
        return outcome
    }
}

private final class FixedClock: ClockProviding, Sendable {
    private let storedNow: Date
    init(now: Date) {
        storedNow = now
    }

    var now: Date { storedNow }
}

struct WeatherServiceTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeCacheDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func makeSnapshot(
        location: WeatherLocation = .defaultCity,
        age: TimeInterval = 0,
        temperature: Double = 25
    ) -> WeatherSnapshot {
        WeatherSnapshot(
            location: location,
            condition: .clearSky,
            temperatureCelsius: temperature,
            apparentTemperatureCelsius: temperature + 1,
            isDay: true,
            observedAt: now,
            fetchedAt: now.addingTimeInterval(-age)
        )
    }

    @Test
    func freshCacheSkipsNetwork() async throws {
        let cacheDirectory = makeCacheDirectory()
        let store = WeatherCacheStore(directoryURL: cacheDirectory)
        try store.write(makeSnapshot(age: 60))
        let client = RecordingWeatherClient(outcome: .failure(.serverError))
        let service = WeatherService(
            client: client,
            cacheDirectory: cacheDirectory,
            clock: FixedClock(now: now)
        )

        let snapshot = try await service.weather(
            for: .defaultCity,
            policy: .refreshIfStale
        )

        #expect(snapshot.temperatureCelsius == 25)
        let requests = await client.requestCount
        #expect(requests == 0)
    }

    @Test
    func expiredCacheRefetchesAndUpdatesCache() async throws {
        let cacheDirectory = makeCacheDirectory()
        let store = WeatherCacheStore(directoryURL: cacheDirectory)
        try store.write(makeSnapshot(age: 45 * 60, temperature: 20))
        let client = RecordingWeatherClient(
            outcome: .snapshot(makeSnapshot(age: 0, temperature: 30))
        )
        let service = WeatherService(
            client: client,
            cacheDirectory: cacheDirectory,
            clock: FixedClock(now: now)
        )

        let snapshot = try await service.weather(
            for: .defaultCity,
            policy: .refreshIfStale
        )

        #expect(snapshot.temperatureCelsius == 30)
        #expect(store.load()?.temperatureCelsius == 30)
    }

    @Test
    func cachedWeatherReturnsUsableStaleSnapshotWithoutNetwork() async throws {
        let cacheDirectory = makeCacheDirectory()
        let store = WeatherCacheStore(directoryURL: cacheDirectory)
        try store.write(makeSnapshot(age: 45 * 60, temperature: 20))
        let client = RecordingWeatherClient(
            outcome: .snapshot(makeSnapshot(temperature: 30))
        )
        let service = WeatherService(
            client: client,
            cacheDirectory: cacheDirectory,
            clock: FixedClock(now: now)
        )

        let snapshot = await service.cachedWeather(for: .defaultCity)

        #expect(snapshot?.temperatureCelsius == 20)
        #expect(await client.requestCount == 0)
    }

    @Test
    func failureWithUsableCacheReturnsCached() async throws {
        let cacheDirectory = makeCacheDirectory()
        let store = WeatherCacheStore(directoryURL: cacheDirectory)
        try store.write(makeSnapshot(age: 2 * 3600, temperature: 22))
        let client = RecordingWeatherClient(outcome: .failure(.offline))
        let service = WeatherService(
            client: client,
            cacheDirectory: cacheDirectory,
            clock: FixedClock(now: now)
        )

        let snapshot = try await service.weather(
            for: .defaultCity,
            policy: .refreshIfStale
        )

        #expect(snapshot.temperatureCelsius == 22)
        #expect(store.load()?.temperatureCelsius == 22)
    }

    @Test
    func failureWithoutAnyCacheThrows() async {
        let client = RecordingWeatherClient(outcome: .failure(.offline))
        let service = WeatherService(
            client: client,
            cacheDirectory: makeCacheDirectory(),
            clock: FixedClock(now: now)
        )

        await #expect(throws: UserFacingError.self) {
            _ = try await service.weather(
                for: .defaultCity,
                policy: .refreshIfStale
            )
        }
    }

    @Test
    func differentLocationBypassesCache() async throws {
        let cacheDirectory = makeCacheDirectory()
        let store = WeatherCacheStore(directoryURL: cacheDirectory)
        try store.write(makeSnapshot(age: 0))
        let shanghai = ManualCity(
            name: "上海",
            admin1: "上海市",
            countryCode: "CN",
            latitude: 31.23,
            longitude: 121.47,
            timezone: "Asia/Shanghai"
        )
        let shanghaiLocation = WeatherLocation(city: shanghai)
        let client = RecordingWeatherClient(
            outcome: .snapshot(makeSnapshot(location: shanghaiLocation))
        )
        let service = WeatherService(
            client: client,
            cacheDirectory: cacheDirectory,
            clock: FixedClock(now: now)
        )

        let snapshot = try await service.weather(
            for: shanghaiLocation,
            policy: .refreshIfStale
        )

        #expect(snapshot.location == shanghaiLocation)
        let requests = await client.requestCount
        #expect(requests == 1)
    }

    @Test
    func clearCacheRemovesDiskFile() async throws {
        let cacheDirectory = makeCacheDirectory()
        let store = WeatherCacheStore(directoryURL: cacheDirectory)
        try store.write(makeSnapshot())
        let service = WeatherService(
            client: RecordingWeatherClient(outcome: .failure(.offline)),
            cacheDirectory: cacheDirectory,
            clock: FixedClock(now: now)
        )

        await service.clearCache()

        #expect(store.load() == nil)
    }
}

// MARK: - AppModel 原子切换

private final class MutableClock: ClockProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var storedNow: Date

    init(now: Date) {
        storedNow = now
    }

    var now: Date {
        lock.withLock { storedNow }
    }
}

private struct CannedWeatherProvider: WeatherProviding {
    enum Mode: Sendable {
        case success(temperature: Double)
        case failure(UserFacingError)
    }

    private let mode: Mode

    init(mode: Mode) {
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

@MainActor
struct WeatherAppModelTests {
    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "CalendaTests.Weather.\(UUID().uuidString)"
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

    @Test
    func panelAppearLoadsDefaultCityWeather() async throws {
        let store = SettingsStore(defaults: try makeDefaults())
        let model = AppModel(
            clock: MutableClock(now: ISO8601DateFormatter().date(from: "2026-08-21T10:00:00Z")!),
            calendarService: CalendarService(timeZone: TimeZone(secondsFromGMT: 0)!),
            settings: store,
            weatherService: CannedWeatherProvider(mode: .success(temperature: 29))
        )

        model.panelWillAppear()
        await drainUntil {
            if case let .loaded(snapshot, _) = model.weatherState {
                return snapshot.location == .defaultCity
            }
            return false
        }

        guard case let .loaded(snapshot, freshness) = model.weatherState else {
            Issue.record("期望 loaded，实际：\(model.weatherState)")
            return
        }
        #expect(snapshot.temperatureCelsius == 29)
        #expect(snapshot.location == .defaultCity)
        #expect(freshness == .fresh)
        model.panelDidDisappear()
    }

    @Test
    func citySwitchPublishesOnlyNewCitySnapshots() async throws {
        let store = SettingsStore(defaults: try makeDefaults())
        let model = AppModel(
            clock: MutableClock(now: ISO8601DateFormatter().date(from: "2026-08-21T10:00:00Z")!),
            calendarService: CalendarService(timeZone: TimeZone(secondsFromGMT: 0)!),
            settings: store,
            weatherService: CannedWeatherProvider(mode: .success(temperature: 31))
        )
        let shanghai = ManualCity(
            name: "上海",
            admin1: "上海市",
            countryCode: "CN",
            latitude: 31.23,
            longitude: 121.47,
            timezone: "Asia/Shanghai"
        )

        model.panelWillAppear()
        await drainUntil {
            if case let .loaded(snapshot, _) = model.weatherState {
                return snapshot.location == .defaultCity
            }
            return false
        }

        store.update { $0.activeLocation = .manual(shanghai) }
        await drainUntil {
            if case let .loaded(snapshot, _) = model.weatherState {
                return snapshot.location == WeatherLocation(city: shanghai)
            }
            return false
        }

        // 新城市名称只搭配新城市天气（设计 12.1 原子切换）
        guard case let .loaded(snapshot, _) = model.weatherState else {
            Issue.record("期望 loaded，实际：\(model.weatherState)")
            return
        }
        #expect(snapshot.location.displayName == "上海")
        #expect(snapshot.temperatureCelsius == 31)
        model.panelDidDisappear()
    }

    @Test
    func failureWithoutCacheKeepsNoPreviousWeather() async throws {
        let store = SettingsStore(defaults: try makeDefaults())
        let model = AppModel(
            clock: MutableClock(now: ISO8601DateFormatter().date(from: "2026-08-21T10:00:00Z")!),
            calendarService: CalendarService(timeZone: TimeZone(secondsFromGMT: 0)!),
            settings: store,
            weatherService: CannedWeatherProvider(mode: .failure(.offline))
        )

        model.panelWillAppear()
        await drainUntil {
            if case .failed = model.weatherState {
                return true
            }
            return false
        }

        guard case let .failed(previous, error) = model.weatherState else {
            Issue.record("期望 failed，实际：\(model.weatherState)")
            return
        }
        #expect(previous == nil)
        #expect(error == .offline)
        model.panelDidDisappear()
    }

    @Test
    func disablingWeatherResetsState() async throws {
        let store = SettingsStore(defaults: try makeDefaults())
        let model = AppModel(
            clock: MutableClock(now: ISO8601DateFormatter().date(from: "2026-08-21T10:00:00Z")!),
            calendarService: CalendarService(timeZone: TimeZone(secondsFromGMT: 0)!),
            settings: store,
            weatherService: CannedWeatherProvider(mode: .success(temperature: 25))
        )

        model.panelWillAppear()
        await drainUntil {
            if case .loaded = model.weatherState {
                return true
            }
            return false
        }

        store.update { $0.isWeatherEnabled = false }
        await drainUntil { model.weatherState == .idle }
        #expect(!model.isWeatherEnabled)
        model.panelDidDisappear()
    }
}
