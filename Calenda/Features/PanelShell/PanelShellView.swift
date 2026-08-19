//
//  PanelShellView.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import SwiftUI

struct PanelShellView: View {
    private enum Presentation {
        static let brandName = "Calenda"
        static let calendarSymbol = "calendar"
        static let escapeKeyLabel = "Esc"
        static let localeIdentifier = "zh_Hans_CN"
        static let headerHeight: CGFloat = 52
        static let footerHeight: CGFloat = 34
        static let detailWidth: CGFloat = 200
        static let horizontalPadding: CGFloat = 24
        static let contentSpacing: CGFloat = 16
        static let calendarSymbolSize: CGFloat = 44
        static let dayFontSize: CGFloat = 112
        static let dividerOpacity = 0.35
    }

    private let date: Date
    private let locale = Locale(identifier: Presentation.localeIdentifier)

    init(date: Date = .now) {
        self.date = date
    }

    var body: some View {
        VStack(spacing: .zero) {
            header
            Divider().opacity(Presentation.dividerOpacity)
            content
            Divider().opacity(Presentation.dividerOpacity)
            footer
        }
        .environment(\.locale, locale)
    }

    private var header: some View {
        HStack {
            Text(date, format: .dateTime.year().month(.wide))
                .font(.title2.weight(.semibold))
            Spacer()
            Text(Presentation.brandName)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Presentation.horizontalPadding)
        .frame(height: Presentation.headerHeight)
    }

    private var content: some View {
        HStack(spacing: .zero) {
            VStack(spacing: Presentation.contentSpacing) {
                Image(systemName: Presentation.calendarSymbol)
                    .font(.system(size: Presentation.calendarSymbolSize, weight: .light))
                    .foregroundStyle(.secondary)
                Text(date, format: .dateTime.day())
                    .font(
                        .system(
                            size: Presentation.dayFontSize,
                            weight: .light,
                            design: .rounded
                        )
                        .monospacedDigit()
                    )
                Text(date, format: .dateTime.weekday(.wide))
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().opacity(Presentation.dividerOpacity)

            VStack(alignment: .leading, spacing: Presentation.contentSpacing) {
                Text(date, format: .dateTime.year().month().day())
                    .font(.title3.weight(.semibold))
                Text(date, format: .dateTime.weekday(.wide))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: Presentation.calendarSymbol)
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
            }
            .padding(Presentation.horizontalPadding)
            .frame(width: Presentation.detailWidth)
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var footer: some View {
        HStack {
            Text(Presentation.brandName)
                .foregroundStyle(.secondary)
            Spacer()
            Text(Presentation.escapeKeyLabel)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Presentation.horizontalPadding)
        .frame(height: Presentation.footerHeight)
    }
}
