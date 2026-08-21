//
//  CalendaMain.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import AppKit

@main
@MainActor
enum CalendaMain {
    private static let appDelegate = AppDelegate()

    static func main() {
        let application = NSApplication.shared
        application.delegate = appDelegate
        application.run()
    }
}
