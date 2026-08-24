//
//  CalendarGrid.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import SwiftUI

private enum CalendarGridPresentation {
    static let weekdayLocaleIdentifier = "zh_Hans_CN"
}

struct CalendarGrid: View {
    private enum Layout {
        static let columnCount = 7
        static let gridSpacing: CGFloat = 1
        static let horizontalPadding: CGFloat = 14
        static let verticalPadding: CGFloat = 8
        static let weekdayFont: Font = .caption.weight(.medium)
    }

    private let model: AppModel
    @Namespace private var selectionNamespace
    /// 日期按钮会随月份整体替换，不能作为持久焦点目标，否则系统会在
    /// 旧按钮移除时把焦点短暂迁移到相邻日期或右侧城市按钮。网格本身
    /// 是唯一且稳定的焦点目标；当前键盘位置由选中背景表达。
    @FocusState private var isGridFocused: Bool

    init(model: AppModel) {
        self.model = model
    }

    var body: some View {
        VStack(spacing: Layout.gridSpacing) {
            weekdayHeader
            dayGrid
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
        .frame(maxHeight: .infinity, alignment: .top)
        .focusable()
        .focused($isGridFocused)
        .focusEffectDisabled()
        .onAppear { focusGridIfVisible() }
        .onChange(of: model.selectedDay) { _, _ in
            focusGridIfVisible()
        }
        .onChange(of: model.isPanelVisible) { _, isVisible in
            isGridFocused = isVisible
        }
    }

    private var dayGrid: some View {
        LazyVGrid(columns: columns, spacing: Layout.gridSpacing) {
            ForEach(Array(model.cells.enumerated()), id: \.element.id) { index, cell in
                CalendarDayCell(
                    cell: cell,
                    isSelected: cell.id == model.selectedDay,
                    badge: model.dayBadge(for: cell.id),
                    holidayMark: model.holidayMark(for: cell.id),
                    isWeekend: weekdays[index % Layout.columnCount].isWeekend,
                    selectionNamespace: selectionNamespace,
                    action: {
                        isGridFocused = true
                        model.select(cell.id)
                    }
                )
                // VoiceOver 仍可逐格操作；这里只排除会参与系统键盘焦点
                // 迁移的 AppKit/SwiftUI focus chain。
                .focusable(false)
            }
        }
    }

    private func focusGridIfVisible() {
        if model.isPanelVisible {
            isGridFocused = true
        }
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: Layout.gridSpacing),
            count: Layout.columnCount
        )
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: Layout.gridSpacing) {
            ForEach(weekdays, id: \.self) { weekday in
                Text(weekday.symbol)
                    .font(Layout.weekdayFont)
                    .foregroundStyle(weekdayHeaderStyle(isWeekend: weekday.isWeekend))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var weekdays: [CalendarWeekday] {
        CalendarWeekday.ordered(startingWith: model.firstWeekday)
    }

    /// 周末仅用次级颜色区分，不自动等同法定节假日（设计 5.4）。
    private func weekdayHeaderStyle(isWeekend: Bool) -> Color {
        isWeekend ? .secondary : .primary.opacity(0.55)
    }
}

private extension CalendarWeekday {
    var symbol: String {
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = Locale(
            identifier: CalendarGridPresentation.weekdayLocaleIdentifier
        )
        let symbols = calendar.veryShortWeekdaySymbols
        let index = rawValue - CalendarWeekday.sunday.rawValue
        return symbols[index]
    }
}
