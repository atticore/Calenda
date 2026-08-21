//
//  Holiday.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Foundation

/// holiday-cn 年度数据的领域模型（设计 10.1）。
/// 记录由 name、date、isOffDay 组成；isOffDay 为 true 表示法定休息日，
/// false 表示调休工作日。papers 为公告链接，只作来源元数据展示。
nonisolated struct HolidayDay: Sendable, Equatable, Codable {
    let name: String
    let date: CalendarDayID
    let isOffDay: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case date
        case isOffDay
    }

    init(name: String, date: CalendarDayID, isOffDay: Bool) {
        self.name = name
        self.date = date
        self.isOffDay = isOffDay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        let dateString = try container.decode(String.self, forKey: .date)
        guard let parsed = HolidayDecoding.parseDate(dateString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .date,
                in: container,
                debugDescription: "日期不是 yyyy-MM-dd 或超出合理范围：\(dateString)"
            )
        }
        date = parsed
        isOffDay = try container.decode(Bool.self, forKey: .isOffDay)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(
            String(
                format: "%04d-%02d-%02d",
                date.year,
                date.month,
                date.day
            ),
            forKey: .date
        )
        try container.encode(isOffDay, forKey: .isOffDay)
    }
}

/// holiday-cn 上游 JSON 的传输 DTO；严格解码后转换为领域模型。
nonisolated struct HolidayYearPayload: Sendable, Equatable, Codable {
    let year: Int
    let papers: [String]
    let days: [HolidayDay]
}

/// 单日展示用的法定作息标记（设计 8.3）。
nonisolated struct HolidayMark: Sendable, Equatable {
    let name: String
    let isOffDay: Bool
}

/// 年度可用性三态（设计 10.6），不把 HTTP 状态码当作领域语义。
nonisolated enum HolidayYearAvailability: Sendable, Equatable {
    /// 该年度有正式安排，正常展示休/班
    case published
    /// 数据源正常但官方安排尚未发布（未来年 404 或空 days）
    case unpublished
    /// 网络、解析或校验失败；当前或过去年份 404 也归入此列
    case unavailable
}

nonisolated enum RefreshPolicy: Sendable, Equatable {
    /// 只读本地数据（bundled 快照与磁盘缓存）
    case cacheOnly
    /// 本地数据超过检查间隔时后台更新
    case refreshIfStale
    /// 用户显式触发（仍受节流保护）
    case forceRefresh
}

/// 返回给 AppModel 的合并视图：按日期合并（跨年时下一年度文件优先，
/// 设计 10.1），并携带各请求年份的可用性。
nonisolated struct HolidaySnapshot: Sendable, Equatable {
    let marksByDay: [CalendarDayID: HolidayMark]
    let availabilityByYear: [Int: HolidayYearAvailability]

    init(
        marksByDay: [CalendarDayID: HolidayMark] = [:],
        availabilityByYear: [Int: HolidayYearAvailability] = [:]
    ) {
        self.marksByDay = marksByDay
        self.availabilityByYear = availabilityByYear
    }

    func mark(for day: CalendarDayID) -> HolidayMark? {
        marksByDay[day]
    }
}

nonisolated protocol HolidayProviding: Sendable {
    func holidays(
        for years: Set<Int>,
        policy: RefreshPolicy
    ) async -> HolidaySnapshot
}

// MARK: - 解码与领域校验

nonisolated enum HolidayValidationError: Error, Equatable, Sendable {
    case yearMismatch(requested: Int, payload: Int)
    case invalidDate(String)
    case emptyName(String)
    case conflictingDay(String)
    case paperURLNotTrusted(String)
}

nonisolated enum HolidayDecoding {
    /// 严格解码 + 领域校验（设计 10.4）：year 匹配请求年份、日期可解析、
    /// name 非空、同一天不得出现冲突记录、公告链接为 gov.cn HTTPS。
    /// 同日期内容一致的重复记录按去重处理。
    static func decodeAndValidate(
        data: Data,
        requestedYear: Int
    ) throws -> HolidayYearPayload {
        let dto = try decoder.decode(DTO.self, from: data)
        guard dto.year == requestedYear else {
            throw HolidayValidationError.yearMismatch(
                requested: requestedYear,
                payload: dto.year
            )
        }

        var papers: [String] = []
        for paperURL in dto.papers ?? [] {
            guard let url = URL(string: paperURL),
                  url.scheme?.lowercased() == "https",
                  let host = url.host?.lowercased(),
                  host == "www.gov.cn" || host.hasSuffix(".gov.cn")
            else {
                throw HolidayValidationError.paperURLNotTrusted(paperURL)
            }
            papers.append(paperURL)
        }

        var daysByDate: [CalendarDayID: HolidayDay] = [:]
        var days: [HolidayDay] = []
        for day in dto.days {
            guard let date = Self.parseDate(day.date) else {
                throw HolidayValidationError.invalidDate(day.date)
            }
            guard !day.name.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw HolidayValidationError.emptyName(day.date)
            }
            let model = HolidayDay(
                name: day.name,
                date: date,
                isOffDay: day.isOffDay
            )
            if let existing = daysByDate[date] {
                guard existing == model else {
                    throw HolidayValidationError.conflictingDay(day.date)
                }
                continue
            }
            daysByDate[date] = model
            days.append(model)
        }

        return HolidayYearPayload(
            year: dto.year,
            papers: papers,
            days: days
        )
    }

    static func parseDate(_ string: String) -> CalendarDayID? {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else {
            return nil
        }
        var calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        guard let date = calendar.date(from: components) else {
            return nil
        }
        // 往返校验拒绝 2 月 30 日这类“基本范围合法但不存在”的日期
        let roundTrip = calendar.dateComponents(
            [.year, .month, .day],
            from: date
        )
        guard
            roundTrip.year == year,
            roundTrip.month == month,
            roundTrip.day == day
        else {
            return nil
        }
        return CalendarDayID(year: year, month: month, day: day)
    }

    private static let decoder = JSONDecoder()

    private struct DTO: Decodable {
        let year: Int
        let papers: [String]?
        let days: [DayDTO]

        struct DayDTO: Decodable {
            let name: String
            let date: String
            let isOffDay: Bool
        }
    }
}
