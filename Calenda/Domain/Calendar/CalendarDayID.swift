//
//  CalendarDayID.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import Foundation

nonisolated struct CalendarDayID: Hashable, Sendable, Codable {
    let year: Int
    let month: Int
    let day: Int
}

