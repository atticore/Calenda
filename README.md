# Calenda

Calenda 是一款原生 macOS 菜单栏日历。点击菜单栏状态项可打开固定尺寸的日历面板，快速查看公历、农历、节气、中国法定节假日与当前天气；不需要账号，也不依赖后端服务。

面板尺寸与右栏宽度以 [PanelConfiguration.swift](Calenda/AppKitShell/PanelConfiguration.swift) 为唯一来源。

## 当前功能

- 42 格公历月历，支持周一、周日或跟随系统作为每周首日。
- 农历、农历节日和二十四节气；Tyme4Swift 仅在应用自有适配层中使用。
- 中国法定节假日和调休标记；安装包内置 2025、2026 年快照，支持受信任镜像链的条件更新与最后有效缓存回退。
- Open-Meteo 当前天气、天气缓存、摄氏/华氏切换、默认北京、手动选城与按需当前位置。
- 月份选择器、日期键盘导航、回到今天、Escape 关闭，以及状态项右键的设置和退出菜单。
- 单实例原生设置窗口，包含显示、天气、节假日更新、登录时启动及缓存/位置清理。

## 面板与交互

面板内容尺寸固定为 590 × 370 pt，右侧详情栏宽 160 pt。月历在左侧，右栏的选中日期位于顶部，选中日期的农历/节气/节假日占用固定的中部槽位；“今天”的天气和节气固定在底部，因此切换日期或天气状态不会推动下方内容。

顶部提供月份选择、上/下月、回到今天和设置。日期格可点击；方向键按天或按周移动，Command 加方向键按月移动，Option 加方向键按年移动，Command + T 回到今天。

## 离线、网络与隐私

公历、农历和节气可离线使用。节假日与天气均先使用内置数据或本地缓存，再按策略后台刷新；网络失败不会阻止月历显示。

位置权限不会在启动时请求。用户仅在选择“使用当前位置”时触发一次性定位，也可始终使用默认北京或手动城市。应用不实现账号、遥测、分析或服务端。网络请求仅面向 holiday-cn 的固定镜像与 Open-Meteo 的固定 HTTPS 主机，并校验重定向目标。

## 技术构成

- macOS 26+、Swift 6 语言模式、完整 Strict Concurrency 检查。
- AppKit 维护 NSStatusItem、NSPanel、定位、焦点、外部点击关闭与设置窗口；SwiftUI 负责面板和设置内容。
- AppModel 是 MainActor 上的可观察 UI 状态所有者；LunarService、HolidayService 和 WeatherService 使用 actor 隔离。
- 小型偏好存储在 UserDefaults；天气和节假日缓存存储在 Application Support 下的 Calenda 子目录。

## 构建与测试

项目共享 scheme 为 Calenda。使用支持 macOS 26 SDK 的 Xcode 27 beta 5 或更新版本执行：

```bash
xcodebuild -project Calenda.xcodeproj -scheme Calenda \
  -configuration Debug -destination 'platform=macOS' build

xcodebuild -project Calenda.xcodeproj -scheme Calenda \
  -configuration Debug -destination 'platform=macOS' \
  -parallel-testing-enabled NO test -only-testing:CalendaTests

xcodebuild -project Calenda.xcodeproj -scheme Calenda \
  -configuration Debug -destination 'platform=macOS' \
  -parallel-testing-enabled NO test \
  -only-testing:CalendaUITests/CalendaUITests/testCombinedHolidayNamesOnlyAnchorsInDayCells
```

单元测试覆盖月历计算、农历适配、节假日和天气缓存/网络回退、位置、设置、菜单栏图标和面板状态机。UI 测试覆盖状态项、键盘关闭、月份选择器、设置窗口与右栏布局锚点；涉及面板生命周期、定位或多显示器的改动仍需在真实 macOS 环境验证。

## 当前边界

仓库尚未包含 CI 配置、LICENSE、THIRD_PARTY_NOTICES、发布签名/公证流程或 Release 产物。这些属于发布工作，而不是当前可构建应用的组成部分。
