//
//  WeatherService.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Foundation
import OSLog

/// 离线兜底客户端：AppModel 默认构造使用，保证单元测试不触网；
/// 应用装配时注入 OpenMeteoClient。
nonisolated struct UnavailableWeatherClient: WeatherFetching {
    func currentWeather(
        for location: WeatherLocation
    ) async -> WeatherFetchOutcome {
        .failure(.offline)
    }
}

/// 天气服务（设计 12.3）：
/// - 同一位置新鲜缓存直接返回；过期缓存触发网络更新；
/// - 网络失败时保留最后一次有效数据（同位置），完全无数据时抛错；
/// - 切换位置不复用旧城市缓存；
/// - 弹窗关闭不取消进行中的刷新（actor 持有任务）。
actor WeatherService: WeatherProviding {
    private static let logger = Logger(
        subsystem: "com.atticore.Calenda",
        category: "weather"
    )

    private let client: any WeatherFetching
    private let cacheStore: WeatherCacheStore
    private let clock: any ClockProviding
    private var cachedSnapshot: WeatherSnapshot?

    init(
        client: any WeatherFetching,
        cacheDirectory: URL? = nil,
        clock: any ClockProviding = SystemClock()
    ) {
        self.client = client
        cacheStore = WeatherCacheStore(directoryURL: cacheDirectory)
        self.clock = clock
    }

    func weather(
        for location: WeatherLocation,
        policy: RefreshPolicy
    ) async throws -> WeatherSnapshot {
        // 内存与磁盘中的同位置缓存互为候选，取较新者
        let cached = Self.newer(
            cachedSnapshot,
            cacheStore.load(),
            at: clock.now
        )
        if let cached {
            cachedSnapshot = cached
        }

        if let cached, cached.location == location {
            let shouldReturnCache: Bool
            switch policy {
            case .cacheOnly:
                shouldReturnCache = true
            case .refreshIfStale:
                shouldReturnCache = WeatherCachePolicy.isUsable(
                    cached,
                    at: clock.now
                )
                && WeatherCachePolicy.freshness(of: cached, at: clock.now)
                    == .fresh
            case .forceRefresh:
                shouldReturnCache = false
            }
            if shouldReturnCache {
                return cached
            }
        }

        let outcome = await client.currentWeather(for: location)
        switch outcome {
        case let .snapshot(snapshot):
            cachedSnapshot = snapshot
            do {
                try cacheStore.write(snapshot)
            } catch {
                Self.logger.error(
                    "天气缓存写入失败：\(error.localizedDescription, privacy: .public)"
                )
            }
            return snapshot
        case let .failure(error):
            // 网络失败：同位置且仍在可用期的缓存兜底（设计 12.3）
            if let cached,
               cached.location == location,
               WeatherCachePolicy.isUsable(cached, at: clock.now)
            {
                Self.logger.debug(
                    "天气刷新失败，返回最后有效数据：\(String(describing: error), privacy: .public)"
                )
                return cached
            }
            throw error
        }
    }

    /// 面板与设置页展示“上次更新时间”用的当前快照。
    func currentSnapshot() -> WeatherSnapshot? {
        cachedSnapshot
    }

    /// 手动刷新入口：绕过新鲜期，但仍复用同位置在途约束。
    func refresh(
        for location: WeatherLocation
    ) async throws -> WeatherSnapshot {
        try await weather(for: location, policy: .forceRefresh)
    }

    /// 清除天气缓存（设置页“清除缓存与位置”，设计 13.4/15.2）。
    func clearCache() {
        cachedSnapshot = nil
        cacheStore.remove()
    }

    private static func newer(
        _ lhs: WeatherSnapshot?,
        _ rhs: WeatherSnapshot?,
        at now: Date
    ) -> WeatherSnapshot? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return lhs.fetchedAt >= rhs.fetchedAt ? lhs : rhs
        case let (lhs?, nil):
            return lhs
        case let (nil, rhs?):
            return rhs
        case (nil, nil):
            return nil
        }
    }
}
