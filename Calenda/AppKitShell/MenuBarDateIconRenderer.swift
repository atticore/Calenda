//
//  MenuBarDateIconRenderer.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import AppKit

/// 菜单栏日期图标：以独立的撕页日历轮廓承载日期，避免数字压在
/// 通用 SF Symbol 上而显得拥挤。
@MainActor
enum MenuBarDateIconRenderer {
    private enum Layout {
        static let iconPointSize: CGFloat = 18
        static let pageInset: CGFloat = 0.75
        static let pageCornerRadius: CGFloat = 3
        static let pageLineWidth: CGFloat = 1.25
        static let headerY: CGFloat = 5.25
        static let headerInset: CGFloat = 1.25
        static let ringStartY: CGFloat = 0.5
        static let ringEndY: CGFloat = 3
        static let firstRingX: CGFloat = 5
        static let secondRingX: CGFloat = 13
        static let dayFontSize: CGFloat = 9.5
        static let twoDigitFontSize: CGFloat = 8.5
        static let dayVerticalCenterY: CGFloat = 10.6
        static let markRadius: CGFloat = 0.7
        static let markColumnPositions: [CGFloat] = [5, 9, 13]
        static let markRowPositions: [CGFloat] = [9.2, 13.1]
    }

    private enum Typography {
        static let dayFontWeight = NSFont.Weight.semibold
    }

    /// 渲染带日内数字的模板图标；系统符号缺失时返回 nil，
    /// 由调用方回退到“无图标 + 文字标题”的旧样式。
    static func icon(
        day: Int,
        calendarSymbolName _: String
    ) -> NSImage? {
        guard (CalendarDayRange.minimum...CalendarDayRange.maximum).contains(day) else {
            return nil
        }

        let iconSize = NSSize(
            width: Layout.iconPointSize,
            height: Layout.iconPointSize
        )
        let image = NSImage(size: iconSize, flipped: true) { canvas in
            drawCalendarPage(in: canvas)
            drawDayNumber(day, in: canvas)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// 无日期模式沿用同一日历页比例，只移除数字，避免切换样式时
    /// 视觉重量和菜单栏占位突然变化。
    static func plainIcon() -> NSImage {
        let iconSize = NSSize(
            width: Layout.iconPointSize,
            height: Layout.iconPointSize
        )
        let image = NSImage(size: iconSize, flipped: true) { canvas in
            drawCalendarPage(in: canvas)
            drawCalendarMarks()
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawCalendarPage(in canvas: NSRect) {
        let page = NSRect(
            x: canvas.minX + Layout.pageInset,
            y: canvas.minY + Layout.pageInset,
            width: canvas.width - Layout.pageInset * 2,
            height: canvas.height - Layout.pageInset * 2
        )
        let pagePath = NSBezierPath(
            roundedRect: page,
            xRadius: Layout.pageCornerRadius,
            yRadius: Layout.pageCornerRadius
        )
        pagePath.lineWidth = Layout.pageLineWidth
        pagePath.stroke()

        let headerPath = NSBezierPath()
        headerPath.move(
            to: NSPoint(x: page.minX + Layout.headerInset, y: Layout.headerY)
        )
        headerPath.line(
            to: NSPoint(x: page.maxX - Layout.headerInset, y: Layout.headerY)
        )
        headerPath.lineWidth = Layout.pageLineWidth
        headerPath.stroke()
        drawBindingRing(at: Layout.firstRingX)
        drawBindingRing(at: Layout.secondRingX)
    }

    private static func drawBindingRing(at horizontalPosition: CGFloat) {
        let ringPath = NSBezierPath()
        ringPath.move(
            to: NSPoint(x: horizontalPosition, y: Layout.ringStartY)
        )
        ringPath.line(
            to: NSPoint(x: horizontalPosition, y: Layout.ringEndY)
        )
        ringPath.lineWidth = Layout.pageLineWidth
        ringPath.lineCapStyle = .round
        ringPath.stroke()
    }

    private static func drawCalendarMarks() {
        for verticalPosition in Layout.markRowPositions {
            for horizontalPosition in Layout.markColumnPositions {
                let diameter = Layout.markRadius * 2
                let markRect = NSRect(
                    x: horizontalPosition - Layout.markRadius,
                    y: verticalPosition - Layout.markRadius,
                    width: diameter,
                    height: diameter
                )
                NSBezierPath(ovalIn: markRect).fill()
            }
        }
    }

    private static func drawDayNumber(
        _ day: Int,
        in canvas: NSRect
    ) {
        let dayFontSize = day >= CalendarDayRange.twoDigitMinimum
            ? Layout.twoDigitFontSize
            : Layout.dayFontSize
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(
                ofSize: dayFontSize,
                weight: Typography.dayFontWeight
            ),
        ]
        let dayText = NSString(string: String(day))
        let textSize = dayText.size(withAttributes: attributes)
        let textOrigin = NSPoint(
            x: (canvas.width - textSize.width) / 2,
            y: Layout.dayVerticalCenterY - textSize.height / 2
        )
        dayText.draw(at: textOrigin, withAttributes: attributes)
    }
}

private enum CalendarDayRange {
    static let minimum = 1
    static let maximum = 31
    static let twoDigitMinimum = 10
}
