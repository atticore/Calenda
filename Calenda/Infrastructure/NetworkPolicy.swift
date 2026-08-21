//
//  NetworkPolicy.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Foundation

/// 网络超时与安全常量集中定义（设计 10.4/17），
/// 不在客户端代码中散落魔法数字。
nonisolated enum NetworkPolicy {
    /// 资源整体超时（秒）
    static let resourceTimeout: TimeInterval = 12

    /// 单请求超时（秒）
    static let requestTimeout: TimeInterval = 8

    /// 响应体最大 256 KiB
    static let maxResponseBytes = 256 * 1024

    /// 受信任的 HTTPS 主机白名单（设计 10.3/12/16）；
    /// 重定向的每一跳都必须落在白名单内。
    static let trustedHosts: Set<String> = [
        "cdn.jsdelivr.net",
        "fastly.jsdelivr.net",
        "raw.githubusercontent.com",
        "api.open-meteo.com",
        "geocoding-api.open-meteo.com",
    ]

    static func isTrusted(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased()
        else {
            return false
        }
        return trustedHosts.contains(host)
    }
}

/// 重定向逐跳校验：目标必须仍是受信任 HTTPS 主机，否则取消请求；
/// 供节假日与天气客户端共用。
final class TrustedRedirectGuard: NSObject, URLSessionDataDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard
            let url = request.url,
            NetworkPolicy.isTrusted(url)
        else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

// MARK: - 城市搜索策略

/// 城市搜索阈值集中定义（设计 11.3）。
nonisolated enum LocationSearchPolicy {
    static let minimumQueryLength = 2
    static let debounceInterval: TimeInterval = 0.35
    static let resultCount = 10
}

// MARK: - 节假日刷新策略

nonisolated enum HolidayRefreshPolicy {
    /// 常规检查间隔：24 小时（设计 10.5）
    static let standardCheckInterval: TimeInterval = 24 * 3600

    /// 每年 10 月至次年 1 月，次年数据的检查间隔缩短为 6 小时
    static let upcomingYearCheckInterval: TimeInterval = 6 * 3600

    /// 设置页手动检查的最短节流：60 秒
    static let manualCheckThrottle: TimeInterval = 60

    /// 目标年份数据的检查间隔：次年数据在 10–12 月与次年 1 月使用短间隔。
    static func checkInterval(
        forYear year: Int,
        currentYear: Int,
        currentMonth: Int
    ) -> TimeInterval {
        if year == currentYear, currentMonth <= 1 {
            return upcomingYearCheckInterval
        }
        if year == currentYear + 1, currentMonth >= 10 {
            return upcomingYearCheckInterval
        }
        return standardCheckInterval
    }
}
