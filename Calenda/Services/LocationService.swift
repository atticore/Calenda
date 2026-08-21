//
//  LocationService.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import CoreLocation
import Foundation

/// CoreLocation 封装（设计 11.1/11.2）：
/// - 权限只在用户显式选择“使用当前位置”后按需请求，拒绝后不再弹窗；
/// - 一次性 requestLocation，公里级 desiredAccuracy，拿到即停；
/// - 水平精度与时间戳校验，拒绝明显过旧或无效坐标；
/// - 坐标经 GeoPoint 归一化（约 0.01°）后仅用于城市级天气；
/// - 反向地理编码使用中文 Locale；不持久化定位轨迹。
@MainActor
final class SystemLocationService: NSObject, Locating {
    private enum Policy {
        static let desiredAccuracy = kCLLocationAccuracyKilometer
        /// 结果时间戳超过该年龄视为明显过旧。
        static let maximumLocationAge: TimeInterval = 60
        /// 城市级天气可接受的水平精度上限（米）。
        static let maximumHorizontalAccuracy: CLLocationAccuracy = 5_000
        /// 授权弹窗等待上限：超时按不可用处理，不循环请求。
        static let authorizationTimeout: TimeInterval = 60
        /// 一次性定位等待上限。
        static let locationTimeout: TimeInterval = 15
        static let geocodingLocale = Locale(identifier: "zh_CN")
        static let fallbackDisplayName = "当前位置"
    }

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let clock: any ClockProviding

    private var authorizationContinuation: CheckedContinuation<Void, any Error>?
    private var locationContinuation: CheckedContinuation<CLLocation, any Error>?
    private var timeoutTask: Task<Void, Never>?

    init(clock: any ClockProviding = SystemClock()) {
        self.clock = clock
        super.init()
        manager.delegate = self
    }

    func currentLocation() async throws -> WeatherLocation {
        try await waitForAuthorization()
        let location = try await requestOneShotLocation()
        return try await reverseGeocode(location)
    }

    // MARK: - 阶段实现

    private func waitForAuthorization() async throws {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return
        case .denied, .restricted:
            throw UserFacingError.locationUnavailable
        default:
            try await withCheckedThrowingContinuation { continuation in
                authorizationContinuation = continuation
                startTimeout(
                    Policy.authorizationTimeout,
                    throwing: .locationUnavailable
                )
                manager.requestWhenInUseAuthorization()
            }
        }
    }

    private func requestOneShotLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            startTimeout(Policy.locationTimeout, throwing: .timeout)
            manager.desiredAccuracy = Policy.desiredAccuracy
            manager.requestLocation()
        }
    }

    private func validate(_ location: CLLocation) throws {
        let age = clock.now.timeIntervalSince(location.timestamp)
        guard age >= 0, age <= Policy.maximumLocationAge else {
            throw UserFacingError.locationUnavailable
        }
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= Policy.maximumHorizontalAccuracy
        else {
            throw UserFacingError.locationUnavailable
        }
    }

    private func reverseGeocode(_ location: CLLocation) async throws -> WeatherLocation {
        try validate(location)
        let placemarks: [CLPlacemark]
        do {
            placemarks = try await geocoder.reverseGeocodeLocation(
                location,
                preferredLocale: Policy.geocodingLocale
            )
        } catch {
            throw UserFacingError.locationUnavailable
        }
        guard let placemark = placemarks.first else {
            throw UserFacingError.locationUnavailable
        }
        let name = placemark.locality
            ?? placemark.subAdministrativeArea
            ?? placemark.administrativeArea
            ?? placemark.name
            ?? Policy.fallbackDisplayName
        return WeatherLocation(
            displayName: name,
            coordinates: GeoPoint(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ),
            timezone: placemark.timeZone?.identifier,
            isCurrentLocation: true
        )
    }

    // MARK: - 续期与超时

    /// 每个阶段最多挂起一个续期；先置 nil 再 resume，
    /// 超时与代理回调竞争时只有先到者生效。
    private func resumeAuthorization(with result: Result<Void, any Error>) {
        guard let continuation = authorizationContinuation else {
            return
        }
        authorizationContinuation = nil
        timeoutTask?.cancel()
        continuation.resume(with: result)
    }

    private func resumeLocation(with result: Result<CLLocation, any Error>) {
        guard let continuation = locationContinuation else {
            return
        }
        locationContinuation = nil
        timeoutTask?.cancel()
        continuation.resume(with: result)
    }

    private func startTimeout(
        _ interval: TimeInterval,
        throwing error: UserFacingError
    ) {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled else {
                return
            }
            self?.handleTimeout(error)
        }
    }

    private func handleTimeout(_ error: UserFacingError) {
        if authorizationContinuation != nil {
            resumeAuthorization(with: .failure(error))
        } else if locationContinuation != nil {
            resumeLocation(with: .failure(error))
        }
    }
}

extension SystemLocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            resumeAuthorization(with: .success(()))
        case .denied, .restricted:
            resumeAuthorization(with: .failure(UserFacingError.locationUnavailable))
        case .notDetermined:
            break
        @unknown default:
            resumeAuthorization(with: .failure(UserFacingError.locationUnavailable))
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        // requestLocation 一次回调；取最后一个（通常最新）。
        guard let location = locations.last else {
            return
        }
        resumeLocation(with: .success(location))
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: any Error
    ) {
        resumeLocation(with: .failure(UserFacingError.locationUnavailable))
    }
}
