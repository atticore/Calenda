//
//  MenuBarDateIconRendererTests.swift
//  CalendaTests
//
//  Created by atticore on 2026/8/21.
//

import AppKit
import Testing
@testable import Calenda

@MainActor
struct MenuBarDateIconRendererTests {
    private enum Fixture {
        static let calendarSymbolName = "calendar"
        static let expectedIconPointSize: CGFloat = 18
        static let day = 19
        static let firstDay = 1
        static let lastDay = 31
    }

    @Test
    func rendersTemplateImageAtMenuBarIconSize() throws {
        let icon = try #require(
            MenuBarDateIconRenderer.icon(
                day: Fixture.day,
                calendarSymbolName: Fixture.calendarSymbolName
            )
        )

        #expect(icon.isTemplate)
        #expect(icon.size.width == Fixture.expectedIconPointSize)
        #expect(icon.size.height == Fixture.expectedIconPointSize)
    }

    @Test
    func rendersWithoutDependingOnAnSFSymbol() throws {
        #expect(
            MenuBarDateIconRenderer.icon(
                day: Fixture.day,
                calendarSymbolName: "calenda.nonexistent.symbol"
            ) != nil
        )
    }

    @Test(arguments: [Fixture.firstDay, Fixture.lastDay])
    func rendersEveryValidCalendarDay(day: Int) throws {
        let icon = try #require(
            MenuBarDateIconRenderer.icon(
                day: day,
                calendarSymbolName: Fixture.calendarSymbolName
            )
        )

        #expect(icon.size.width == Fixture.expectedIconPointSize)
    }

    @Test
    func rendersPlainIconAtTheSameMenuBarSize() {
        let icon = MenuBarDateIconRenderer.plainIcon()

        #expect(icon.isTemplate)
        #expect(icon.size.width == Fixture.expectedIconPointSize)
        #expect(icon.size.height == Fixture.expectedIconPointSize)
    }
}
