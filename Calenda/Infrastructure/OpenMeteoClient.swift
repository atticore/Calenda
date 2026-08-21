//
//  OpenMeteoClient.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Foundation

nonisolated enum WeatherFetchOutcome: Sendable, Equatable {
    case snapshot(WeatherSnapshot)
    case failure(UserFacingError)
}

nonisolated protocol WeatherFetching: Sendable {
    func currentWeather(
        for location: WeatherLocation
    ) async -> WeatherFetchOutcome
}

nonisolated protocol CitySearching: Sendable {
    func searchCities(
        matching query: String
    ) async -> Result<[ManualCity], UserFacingError>
}

/// Open-Meteo 客户端（设计 12）：
/// - 请求 URL 一律由 URLComponents 构造，不手工拼接用户输入；
/// - 只请求当前天气所需字段，统一传输摄氏度；
/// - 未知 weather code 映射 unknown，不因上游新增枚举解码失败；
/// - 仅接受受信任 HTTPS 主机的 2xx 响应，体积受 NetworkPolicy 限制。
nonisolated final class OpenMeteoClient: WeatherFetching, CitySearching, Sendable {
    private enum Endpoint {
        static let forecastHost = "api.open-meteo.com"
        static let forecastPath = "/v1/forecast"
        static let geocodingHost = "geocoding-api.open-meteo.com"
        static let geocodingPath = "/v1/search"
        static let currentFields = "temperature_2m,apparent_temperature,weather_code,is_day"
        static let geocodingLanguage = "zh"
        static let responseFormat = "json"
        /// 城市本地时间格式，如 2026-08-21T12:30
        static let observedTimeFormat = "yyyy-MM-dd'T'HH:mm"
    }

    private let session: URLSession
    private let isNetworkDisabled: Bool
    private let nowProvider: @Sendable () -> Date

    init(
        protocolClasses: [AnyClass]? = nil,
        nowProvider: @escaping @Sendable () -> Date = { .now }
    ) {
        isNetworkDisabled = ProcessInfo.processInfo.environment[
            "CALENDA_DISABLE_NETWORK_REFRESH"
        ] == "1"
        self.nowProvider = nowProvider

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = NetworkPolicy.requestTimeout
        configuration.timeoutIntervalForResource = NetworkPolicy.resourceTimeout
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        if let protocolClasses {
            configuration.protocolClasses = protocolClasses
        }
        session = URLSession(
            configuration: configuration,
            delegate: TrustedRedirectGuard(),
            delegateQueue: nil
        )
    }

    deinit {
        session.finishTasksAndInvalidate()
    }

    // MARK: - 当前天气

    func currentWeather(
        for location: WeatherLocation
    ) async -> WeatherFetchOutcome {
        guard !isNetworkDisabled else {
            return .failure(.offline)
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = Endpoint.forecastHost
        components.path = Endpoint.forecastPath
        components.queryItems = [
            URLQueryItem(
                name: "latitude",
                value: String(location.coordinates.latitude)
            ),
            URLQueryItem(
                name: "longitude",
                value: String(location.coordinates.longitude)
            ),
            URLQueryItem(name: "current", value: Endpoint.currentFields),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = components.url, NetworkPolicy.isTrusted(url) else {
            return .failure(.invalidResponse)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: URLRequest(url: url))
        } catch {
            return .failure(Self.mapTransportError(error))
        }
        guard
            let httpResponse = response as? HTTPURLResponse,
            NetworkPolicy.isTrusted(httpResponse.url ?? url)
        else {
            return .failure(.invalidResponse)
        }
        guard httpResponse.statusCode == 200 else {
            return .failure(Self.mapStatusCode(httpResponse.statusCode))
        }
        guard data.count <= NetworkPolicy.maxResponseBytes else {
            return .failure(.invalidResponse)
        }

        do {
            let dto = try JSONDecoder().decode(ForecastDTO.self, from: data)
            return .snapshot(try Self.makeSnapshot(dto: dto, location: location, fetchedAt: nowProvider()))
        } catch {
            return .failure(.invalidResponse)
        }
    }

    // MARK: - 城市搜索

    func searchCities(
        matching query: String
    ) async -> Result<[ManualCity], UserFacingError> {
        guard !isNetworkDisabled else {
            return .failure(.offline)
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = Endpoint.geocodingHost
        components.path = Endpoint.geocodingPath
        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(
                name: "count",
                value: String(LocationSearchPolicy.resultCount)
            ),
            URLQueryItem(name: "language", value: Endpoint.geocodingLanguage),
            URLQueryItem(name: "format", value: Endpoint.responseFormat),
        ]
        guard let url = components.url, NetworkPolicy.isTrusted(url) else {
            return .failure(.invalidResponse)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: URLRequest(url: url))
        } catch {
            return .failure(Self.mapTransportError(error))
        }
        guard
            let httpResponse = response as? HTTPURLResponse,
            NetworkPolicy.isTrusted(httpResponse.url ?? url)
        else {
            return .failure(.invalidResponse)
        }
        guard
            httpResponse.statusCode == 200,
            data.count <= NetworkPolicy.maxResponseBytes
        else {
            return .failure(Self.mapStatusCode(httpResponse.statusCode))
        }

        do {
            let dto = try JSONDecoder().decode(GeocodingDTO.self, from: data)
            let cities = (dto.results ?? []).compactMap { result in
                ManualCity(
                    name: result.name,
                    admin1: result.admin1 ?? "",
                    countryCode: result.countryCode ?? "",
                    latitude: result.latitude,
                    longitude: result.longitude,
                    timezone: result.timezone ?? ""
                )
            }
            return .success(cities)
        } catch {
            return .failure(.invalidResponse)
        }
    }

    // MARK: - 映射

    private static func makeSnapshot(
        dto: ForecastDTO,
        location: WeatherLocation,
        fetchedAt: Date
    ) throws -> WeatherSnapshot {
        guard let current = dto.current else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: [],
                    debugDescription: "缺少 current 字段"
                )
            )
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = Endpoint.observedTimeFormat
        // 城市本地墙钟时间按 utc_offset_seconds 折算为时间点（设计 12.1）
        guard
            let wallClock = formatter.date(from: current.time)
        else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: [],
                    debugDescription: "current.time 不可解析：\(current.time)"
                )
            )
        }
        let observedAt = wallClock.addingTimeInterval(
            -Double(dto.utcOffsetSeconds ?? 0)
        )
        return WeatherSnapshot(
            location: location,
            condition: WeatherCondition(wmoCode: current.weatherCode),
            temperatureCelsius: current.temperatureCelsius,
            apparentTemperatureCelsius: current.apparentTemperatureCelsius,
            isDay: current.isDay == 1,
            observedAt: observedAt,
            fetchedAt: fetchedAt
        )
    }

    private static func mapStatusCode(_ statusCode: Int) -> UserFacingError {
        switch statusCode {
        case 429:
            return .rateLimited
        case 400...499:
            return .invalidResponse
        default:
            return .serverError
        }
    }

    private static func mapTransportError(_ error: Error) -> UserFacingError {
        if error is CancellationError {
            return .offline
        }
        let nsError = error as NSError
        switch nsError.code {
        case NSURLErrorTimedOut:
            return .timeout
        case NSURLErrorCannotConnectToHost,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorNotConnectedToInternet,
             NSURLErrorDNSLookupFailed:
            return .offline
        default:
            return .offline
        }
    }

    private struct ForecastDTO: Decodable {
        let current: CurrentDTO?
        let utcOffsetSeconds: Int?

        enum CodingKeys: String, CodingKey {
            case current
            case utcOffsetSeconds = "utc_offset_seconds"
        }

        struct CurrentDTO: Decodable {
            let time: String
            let temperatureCelsius: Double
            let apparentTemperatureCelsius: Double
            let weatherCode: Int
            let isDay: Int

            enum CodingKeys: String, CodingKey {
                case time
                case temperatureCelsius = "temperature_2m"
                case apparentTemperatureCelsius = "apparent_temperature"
                case weatherCode = "weather_code"
                case isDay = "is_day"
            }
        }
    }

    private struct GeocodingDTO: Decodable {
        let results: [ResultDTO]?

        struct ResultDTO: Decodable {
            let name: String
            let admin1: String?
            let countryCode: String?
            let latitude: Double
            let longitude: Double
            let timezone: String?

            enum CodingKeys: String, CodingKey {
                case name
                case admin1
                case countryCode = "country_code"
                case latitude
                case longitude
                case timezone
            }
        }
    }
}
