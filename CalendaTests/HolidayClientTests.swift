//
//  HolidayClientTests.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Foundation
import Testing
@testable import Calenda

/// 通过自定义 URLProtocol 注入确定性响应（设计 18.2），
/// 不在普通测试中访问真实公网。
final class HolidayStubProtocol: URLProtocol {
    private struct Stub {
        let status: Int
        let headers: [String: String]
        let data: Data
    }

    private static let lock = NSLock()
    // nonisolated(unsafe)：访问始终经由 lock，串行化由测试套件
    // 的 .serialized 进一步保证。
    private nonisolated(unsafe) static var stubsByHost: [String: Stub] = [:]
    private nonisolated(unsafe) static var requestedHosts: [String] = []
    private nonisolated(unsafe) static var lastRequestedURLString: String?

    static func stub(
        host: String,
        status: Int,
        headers: [String: String] = [:],
        data: Data = Data()
    ) {
        lock.withLock {
            stubsByHost[host] = Stub(
                status: status,
                headers: headers,
                data: data
            )
        }
    }

    static func reset() {
        lock.withLock {
            stubsByHost = [:]
            requestedHosts = []
            lastRequestedURLString = nil
        }
    }

    static var hostsRequested: [String] {
        lock.withLock { requestedHosts }
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
            Self.requestedHosts.append(host)
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
            headerFields: stub.headers
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
struct HolidayClientTests {
    private func makeClient() -> HolidayClient {
        HolidayClient(protocolClasses: [HolidayStubProtocol.self])
    }

    private func validPayloadData() -> Data {
        Data(
            """
            {"year":2027,"papers":["https://www.gov.cn/zhengce/x.htm"],"days":[
              {"name":"元旦","date":"2027-01-01","isOffDay":true}
            ]}
            """.utf8
        )
    }

    private func setUp() {
        HolidayStubProtocol.reset()
    }

    @Test
    func fallsBackToSecondMirrorWhenFirstFails() async {
        setUp()
        HolidayStubProtocol.stub(
            host: "cdn.jsdelivr.net",
            status: 500
        )
        HolidayStubProtocol.stub(
            host: "fastly.jsdelivr.net",
            status: 200,
            headers: ["ETag": "\"v1\""],
            data: validPayloadData()
        )

        let result = await makeClient().fetch(
            year: 2026,
            etag: nil,
            lastModified: nil
        )

        guard case let .payload(data, etag, _, sourceURL) = result else {
            Issue.record("期望得到 payload，实际：\(result)")
            return
        }
        #expect(data == validPayloadData())
        #expect(etag == "\"v1\"")
        #expect(sourceURL.contains("fastly.jsdelivr.net"))
        #expect(
            HolidayStubProtocol.hostsRequested
                == ["cdn.jsdelivr.net", "fastly.jsdelivr.net"]
        )
    }

    @Test
    func returnsNotModifiedOn304() async {
        setUp()
        HolidayStubProtocol.stub(host: "cdn.jsdelivr.net", status: 304)

        let result = await makeClient().fetch(
            year: 2026,
            etag: "\"v1\"",
            lastModified: nil
        )

        #expect(result == .notModified)
        #expect(HolidayStubProtocol.hostsRequested == ["cdn.jsdelivr.net"])
    }

    @Test
    func reportsFailureWhenAllMirrorsFail() async {
        setUp()
        for host in NetworkPolicy.trustedHosts {
            HolidayStubProtocol.stub(host: host, status: 503)
        }

        let result = await makeClient().fetch(
            year: 2026,
            etag: nil,
            lastModified: nil
        )

        guard case .failed = result else {
            Issue.record("期望失败，实际：\(result)")
            return
        }
        #expect(HolidayStubProtocol.hostsRequested.count == 3)
    }

    @Test
    func rejectsOversizedResponses() async {
        setUp()
        let oversized = Data(repeating: 0x20, count: NetworkPolicy.maxResponseBytes + 1)
        for host in NetworkPolicy.trustedHosts {
            HolidayStubProtocol.stub(
                host: host,
                status: 200,
                data: oversized
            )
        }

        let result = await makeClient().fetch(
            year: 2026,
            etag: nil,
            lastModified: nil
        )

        guard case .failed = result else {
            Issue.record("超限响应必须被拒绝，实际：\(result)")
            return
        }
    }

    @Test
    func treatsAllMirror404AsNotFound() async {
        setUp()
        for host in NetworkPolicy.trustedHosts {
            HolidayStubProtocol.stub(host: host, status: 404)
        }

        let result = await makeClient().fetch(
            year: 2026,
            etag: nil,
            lastModified: nil
        )

        guard case .notFound = result else {
            Issue.record("期望失败，实际：\(result)")
            return
        }
    }
}

@Suite(.serialized)
struct HolidayClientServiceIntegrationTests {
    @Test
    func allMirror404MarksFutureYearUnpublished() async {
        let emptyBundle = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let manifest = HolidayDataManifest(entries: [
            HolidayDataManifest.Entry(
                year: 2031,
                sourceRevision: "test-revision",
                expectedSHA256: "test-sha256"
            ),
        ])
        let service = HolidayService(
            cacheDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true),
            bundleURL: emptyBundle,
            client: HolidayClient(
                manifest: manifest,
                protocolClasses: [HolidayStubProtocol.self]
            ),
            manifest: manifest
        )
        HolidayStubProtocol.reset()
        for host in NetworkPolicy.trustedHosts {
            HolidayStubProtocol.stub(host: host, status: 404)
        }

        let snapshot = await service.holidays(
            for: [2031],
            policy: .forceRefresh
        )

        #expect(snapshot.availabilityByYear[2031] == .unpublished)
        #expect(HolidayStubProtocol.hostsRequested.count == 3)
    }
}

// MARK: - Service 刷新行为（协议替身，不触网络）

private actor FakeHolidayClient: HolidayFetching {
    private let resultsByYear: [Int: HolidayFetchResult]

    init(resultsByYear: [Int: HolidayFetchResult]) {
        self.resultsByYear = resultsByYear
    }

    func fetch(
        year: Int,
        etag: String?,
        lastModified: String?
    ) async -> HolidayFetchResult {
        resultsByYear[year] ?? .failed("未配置该年份的替身响应")
    }
}

private final class FixedClock: ClockProviding, Sendable {
    private let storedNow: Date
    init(now: Date) {
        storedNow = now
    }

    var now: Date { storedNow }
}

struct HolidayServiceRefreshTests {
    private let emptyBundle: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    private func makeService(
        client: (any HolidayFetching)? = nil,
        manifest: HolidayDataManifest = HolidayDataManifest(),
        clock: any ClockProviding = FixedClock(
            now: ISO8601DateFormatter().date(from: "2026-08-21T10:00:00Z")!
        )
    ) -> HolidayService {
        HolidayService(
            cacheDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true),
            bundleURL: emptyBundle,
            clock: clock,
            client: client,
            manifest: manifest
        )
    }

    private func payloadData(year: Int) -> Data {
        Data(
            """
            {"year":\(year),"papers":["https://www.gov.cn/zhengce/x.htm"],"days":[
              {"name":"元旦","date":"\(year)-01-01","isOffDay":true}
            ]}
            """.utf8
        )
    }

    private func manifest(
        for data: Data,
        year: Int
    ) -> HolidayDataManifest {
        HolidayDataManifest(entries: [
            HolidayDataManifest.Entry(
                year: year,
                sourceRevision: "test-revision",
                expectedSHA256: HolidayCacheStore.sha256Hex(of: data)
            ),
        ])
    }

    private func sourceURL(
        for data: Data,
        year: Int
    ) -> String {
        let entry = manifest(for: data, year: year).entry(for: year)!
        return HolidayDataSource.jsdelivrCDN.url(for: entry).absoluteString
    }

    @Test
    func refreshWritesValidatedPayloadToCache() async throws {
        let payload = payloadData(year: 2027)
        let service = makeService(
            client: FakeHolidayClient(resultsByYear: [
                2027: .payload(
                    payload,
                    etag: "\"a\"",
                    lastModified: nil,
                    sourceURL: sourceURL(for: payload, year: 2027)
                ),
            ]),
            manifest: manifest(for: payload, year: 2027)
        )

        let snapshot = await service.holidays(
            for: [2027],
            policy: .forceRefresh
        )

        #expect(snapshot.availabilityByYear[2027] == .published)
        #expect(
            snapshot.mark(for: CalendarDayID(year: 2027, month: 1, day: 1))
                == HolidayMark(name: "元旦", isOffDay: true)
        )
    }

    @Test
    func refreshFailureDoesNotUseLegacyUnverifiedCache() async throws {
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = HolidayCacheStore(directoryURL: cacheDirectory)
        try store.write(
            HolidayCacheEntry(
                payload: HolidayYearPayload(
                    year: 2026,
                    papers: [],
                    days: [
                        HolidayDay(
                            name: "春节",
                            date: CalendarDayID(year: 2026, month: 2, day: 17),
                            isOffDay: true
                        ),
                    ]
                ),
                sourceURL: "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/2026.json",
                etag: nil,
                lastModified: nil,
                fetchedAt: Date(timeIntervalSince1970: 1_000),
                sha256: "old"
            ),
            for: 2026
        )
        let service = HolidayService(
            cacheDirectory: cacheDirectory,
            bundleURL: emptyBundle,
            client: FakeHolidayClient(resultsByYear: [:])
        )

        let snapshot = await service.holidays(
            for: [2026],
            policy: .forceRefresh
        )

        #expect(snapshot.availabilityByYear[2026] == .unavailable)
        #expect(snapshot.marksByDay.isEmpty)
        #expect(
            store.entry(for: 2026)?.fetchedAt
                == Date(timeIntervalSince1970: 1_000)
        )
    }

    @Test
    func notModifiedDoesNotRewriteCache() async throws {
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = HolidayCacheStore(directoryURL: cacheDirectory)
        let originalEntry = HolidayCacheEntry(
            payload: HolidayYearPayload(year: 2026, papers: [], days: []),
            sourceURL: "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/2026.json",
            etag: "\"v1\"",
            lastModified: nil,
            fetchedAt: Date(timeIntervalSince1970: 2_000),
            sha256: "old"
        )
        try store.write(originalEntry, for: 2026)
        let service = HolidayService(
            cacheDirectory: cacheDirectory,
            bundleURL: emptyBundle,
            client: FakeHolidayClient(resultsByYear: [2026: .notModified])
        )

        _ = await service.holidays(for: [2026], policy: .forceRefresh)

        #expect(store.entry(for: 2026) == originalEntry)
    }

    @Test
    func futureYearNotFoundReportsUnpublished() async {
        let service = makeService(
            client: FakeHolidayClient(resultsByYear: [2031: .notFound])
        )

        let snapshot = await service.holidays(
            for: [2031],
            policy: .forceRefresh
        )

        #expect(snapshot.availabilityByYear[2031] == .unpublished)
    }

    @Test
    func currentYearNotFoundReportsUnavailable() async {
        let service = makeService(
            client: FakeHolidayClient(resultsByYear: [2026: .notFound])
        )

        let snapshot = await service.holidays(
            for: [2026],
            policy: .forceRefresh
        )

        #expect(snapshot.availabilityByYear[2026] == .unavailable)
    }

    @Test
    func invalidRemotePayloadIsRejectedAndNotCached() async {
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let invalidPayload = Data(
            "{\"year\":2099,\"papers\":[],\"days\":[]}".utf8
        )
        let service = HolidayService(
            cacheDirectory: cacheDirectory,
            bundleURL: emptyBundle,
            client: FakeHolidayClient(resultsByYear: [
                2026: .payload(
                    invalidPayload,
                    etag: nil,
                    lastModified: nil,
                    sourceURL: sourceURL(for: invalidPayload, year: 2026)
                ),
            ]),
            manifest: manifest(for: invalidPayload, year: 2026)
        )

        let snapshot = await service.holidays(
            for: [2026],
            policy: .forceRefresh
        )

        #expect(snapshot.availabilityByYear[2026] == .unavailable)
        #expect(snapshot.marksByDay.isEmpty)
        let store = HolidayCacheStore(directoryURL: cacheDirectory)
        #expect(store.entry(for: 2026) == nil)
    }

    @Test
    func forgedPayloadWithApprovedSourceIsRejectedAndNotCached() async {
        let trustedPayload = payloadData(year: 2026)
        let forgedPayload = Data(
            """
            {"year":2026,"papers":["https://www.gov.cn/zhengce/x.htm"],"days":[
              {"name":"伪造节假日","date":"2026-01-01","isOffDay":true}
            ]}
            """.utf8
        )
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let service = HolidayService(
            cacheDirectory: cacheDirectory,
            bundleURL: emptyBundle,
            client: FakeHolidayClient(resultsByYear: [
                2026: .payload(
                    forgedPayload,
                    etag: nil,
                    lastModified: nil,
                    sourceURL: sourceURL(for: trustedPayload, year: 2026)
                ),
            ]),
            manifest: manifest(for: trustedPayload, year: 2026)
        )

        let snapshot = await service.holidays(
            for: [2026],
            policy: .forceRefresh
        )

        #expect(snapshot.availabilityByYear[2026] == .unavailable)
        #expect(snapshot.marksByDay.isEmpty)
        let store = HolidayCacheStore(directoryURL: cacheDirectory)
        #expect(store.entry(for: 2026) == nil)
    }

    @Test
    func manualCheckIsThrottled() async {
        let service = makeService(
            client: FakeHolidayClient(resultsByYear: [2026: .notFound])
        )

        _ = await service.checkForUpdates(years: [2026])
        let summaries = await service.checkForUpdates(years: [2026])

        // 第二次手动检查在 60 秒节流内被跳过，仍给出可用性摘要
        #expect(summaries.count == 1)
        #expect(summaries.first?.availability == .unavailable)
    }
}
