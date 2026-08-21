//
//  SettingsMigration.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Foundation

/// 设置 schema 版本迁移（设计 14/18.1）：启动时执行一次，
/// 步骤按版本升序排列，必须幂等。
enum SettingsMigration {
    static let currentSchemaVersion = 1

    /// 各版本升级步骤：key 为目标版本，值为从上一版本升级的动作。
    /// v1 为初始 schema，尚无历史步骤。
    private static let steps: [Int: (UserDefaults) -> Void] = [:]

    static func migrateIfNeeded(in defaults: UserDefaults) {
        let storedVersion = (defaults.object(forKey: Keys.schemaVersion)
            as? Int) ?? currentSchemaVersion

        guard storedVersion < currentSchemaVersion else {
            if storedVersion == currentSchemaVersion {
                return
            }
            // 高于当前版本（例如回滚安装）：视为全新布局，重置版本号，
            // 字段级未知值回退在 SettingsStore.load 中兜底。
            defaults.set(currentSchemaVersion, forKey: Keys.schemaVersion)
            return
        }

        for version in (storedVersion + 1)...currentSchemaVersion {
            steps[version]?(defaults)
        }
        defaults.set(currentSchemaVersion, forKey: Keys.schemaVersion)
    }

    private enum Keys {
        static let schemaVersion = "settings.schemaVersion"
    }
}
