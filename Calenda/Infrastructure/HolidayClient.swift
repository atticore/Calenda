//
//  HolidayClient.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Foundation

nonisolated enum HolidayFetchResult: Sendable, Equatable {
    /// 304：缓存仍然有效，不改写（设计 10.4）
    case notModified
    /// 404：未来年份视为“尚未发布”信号，当前或过去年份视为不可用（10.6）
    case notFound
    /// 通过传输层检查的响应体，领域校验在 Service 侧执行
    case payload(Data, etag: String?, lastModified: String?, sourceURL: String)
    /// 全部源失败
    case failed(String)
}

nonisolated protocol HolidayFetching: Sendable {
    func fetch(
        year: Int,
        etag: String?,
        lastModified: String?
    ) async -> HolidayFetchResult
}

/// holiday-cn 受信任镜像链客户端（设计 10.3/10.4）：
/// 按固定顺序回退，取得首个可接受的响应即停止；
/// 仅接受 HTTPS、2xx/304，限制响应体大小，重定向逐跳校验主机。
nonisolated final class HolidayClient: HolidayFetching, Sendable {
    private let session: URLSession
    private let isNetworkDisabled: Bool

    enum Source: CaseIterable, Sendable {
        case jsdelivrCDN
        case jsdelivrFastly
        case githubRaw

        func url(for year: Int) -> URL {
            switch self {
            case .jsdelivrCDN:
                return url(
                    host: "cdn.jsdelivr.net",
                    year: year
                )
            case .jsdelivrFastly:
                return url(
                    host: "fastly.jsdelivr.net",
                    year: year
                )
            case .githubRaw:
                return url(
                    host: "raw.githubusercontent.com",
                    year: year
                )
            }
        }

        private func url(host: String, year: Int) -> URL {
            var components = URLComponents()
            components.scheme = "https"
            components.host = host
            let suffix: String
            switch self {
            case .jsdelivrCDN, .jsdelivrFastly:
                suffix = "gh/NateScarlet/holiday-cn@master"
            case .githubRaw:
                suffix = "NateScarlet/holiday-cn/master"
            }
            components.path = "/\(suffix)/\(year).json"
            return components.url!
        }
    }

    init(protocolClasses: [AnyClass]? = nil) {
        isNetworkDisabled = ProcessInfo.processInfo.environment[
            "CALENDA_DISABLE_NETWORK_REFRESH"
        ] == "1"

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

    func fetch(
        year: Int,
        etag: String?,
        lastModified: String?
    ) async -> HolidayFetchResult {
        guard !isNetworkDisabled else {
            return .failed("网络刷新已被测试环境禁用")
        }

        var lastFailure = "无可用镜像源"
        for source in Source.allCases {
            let url = source.url(for: year)
            guard NetworkPolicy.isTrusted(url) else {
                continue
            }

            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            if let etag {
                request.setValue(etag, forHTTPHeaderField: "If-None-Match")
            }
            if let lastModified {
                request.setValue(
                    lastModified,
                    forHTTPHeaderField: "If-Modified-Since"
                )
            }

            do {
                let (data, response) = try await session.data(for: request)
                guard
                    let httpResponse = response as? HTTPURLResponse,
                    let actualURL = httpResponse.url ?? request.url,
                    NetworkPolicy.isTrusted(actualURL)
                else {
                    lastFailure = "响应来源不受信任"
                    continue
                }
                switch httpResponse.statusCode {
                case 200:
                    guard data.count <= NetworkPolicy.maxResponseBytes else {
                        lastFailure = "响应体超过大小限制"
                        continue
                    }
                    return .payload(
                        data,
                        etag: httpResponse.value(forHTTPHeaderField: "ETag"),
                        lastModified: httpResponse.value(
                            forHTTPHeaderField: "Last-Modified"
                        ),
                        sourceURL: actualURL.absoluteString
                    )
                case 304:
                    return .notModified
                case 404:
                    lastFailure = "镜像未收录该年份（404）"
                    continue
                default:
                    lastFailure = "意外状态码 \(httpResponse.statusCode)"
                    continue
                }
            } catch {
                lastFailure = error.localizedDescription
                continue
            }
        }
        // 三个源均返回 404 时按“未收录”上报，由 Service 结合
        // 年份语义判定 unpublished / unavailable（设计 10.6）。
        return .failed(lastFailure)
    }
}

/// 重定向逐跳校验（设计 10.4）：目标必须仍是受信任 HTTPS 主机，
/// 否则取消该请求。
private final class TrustedRedirectGuard: NSObject, URLSessionDataDelegate, Sendable {
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
