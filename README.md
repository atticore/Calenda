# Calenda

Calenda 是仅驻留在 macOS 菜单栏的原生日历工具。它在一个紧凑的原生
面板中提供公历月历、农历、节气、中国法定节假日、调休与当前天气。

设计背景和架构说明见 [DESIGN.md](DESIGN.md)；当前面板尺寸与布局常量
以 [PanelConfiguration.swift](Calenda/AppKitShell/PanelConfiguration.swift)
和 SwiftUI 实现为准。

## 主要功能

- 公历月历，以及周一/周日起始设置
- 农历日期、农历节日和二十四节气
- 中国法定节假日、调休标记与离线内置快照
- Open-Meteo 当前天气、缓存、手动选城与按需定位
- 键盘日期导航、月份选择器、回到今天和 Escape 关闭
- 原生菜单栏状态项、设置窗口、多显示器与 Spaces 支持

## 面板布局

当前面板内容尺寸为 590 × 370 pt，保持固定、紧凑且适合菜单栏快速查看：

- 左侧月历保留稳定宽度，日期格不会因右栏调整而缩小。
- 右侧详情栏宽 160 pt。
- 选中日期固定在右上，显示日期数字、星期、农历、节气或节假日。
- 中部为选中日期的扩展信息预留固定槽位。
- “今天”的天气和节气固定在右下，不随选中日期变化。
- 可选内容和天气状态使用固定高度，避免界面上下跳动。

年月选择器、今天按钮与城市选择均提供符合 macOS 习惯的悬浮反馈；
悬浮背景和实际点击区域保持一致，城市入口不会铺满整行。

## 离线与隐私

公历、农历和节气可完全离线使用。节假日和天气不可用时会显示缓存、
最后一次有效数据或明确的降级状态，不会阻止月历显示。

位置权限是可选的。用户可以独立使用默认北京或手动选择城市；只有主动
选择“使用当前位置”时才需要位置能力。应用不包含账号、分析或遥测。

## 系统要求

- macOS 26+
- Xcode 27 beta 5+
- Swift 6.4 编译器，Swift 6 语言模式

## 构建与测试

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

布局 UI 测试会验证：切换月份时右侧工具栏不移动；选择具有不同节假日
内容的日期时，“今天”区域不移动；并保存最终面板截图供视觉检查。

## 实施进度

| 阶段 | 内容 | 状态 |
|---|---|---|
| Phase 0 | AppKit 外壳：状态项、面板定位、焦点、键盘导航 | ✅ 完成 |
| Phase 1 | 离线核心：公历/农历/节气、动画、节假日内置快照与网络更新 | ✅ 完成 |
| Phase 2 | 节假日：holiday-cn 三镜像条件更新、设置页检查入口 | ✅ 完成 |
| Phase 3 | 天气与位置：Open-Meteo 当前天气、缓存策略、手动选城、CoreLocation 一次性定位、隐私与存储清理 | ✅ 完成 |
| Phase 4 | 发布质量：性能、签名公证、第三方声明、LICENSE | ⬜ 待实施 |

## Shell Spike 实机验证矩阵

设计第 22 章将以下链路列为 Phase 0 阻塞门禁：
状态项点击 → 面板定位 → 激活 → 键盘焦点 → 方向键导航 → Escape/外部点击关闭。
在进入后续阶段前，以下场景需逐项在实机上人工验证并更新本表。

| 场景 | 状态 | 验证方式 |
|---|---|---|
| 普通桌面：打开/关闭/键盘导航/Escape | ✅ 通过 | XCUITest `testStatusItemTogglesPanel` / `testEscapeClosesPanel` + 实机截图 |
| 其他应用前台时打开面板 | ✅ 通过 | 实机截图（navigation 阶段） |
| 面板内键盘导航（方向键/Command/Option/Command+T） | ✅ 通过 | 实机截图（keyboard-navigation 阶段） |
| 年月选择器 popover（打开/选择/Escape 分层关闭） | ✅ 通过 | 实机截图（month-picker 阶段） |
| 右键状态项弹出设置/退出菜单 | 🔶 已实现，待实机验证 | stage 0.7 引入 |
| 设置窗口单实例、Command + , 打开 | 🔶 已实现，待实机验证 | stage 0.7 引入 |
| 全屏应用（fullScreenAuxiliary）| ⬜ 待验证 | 人工 |
| 其他 Space（canJoinAllSpaces）| ⬜ 待验证 | 人工 |
| Stage Manager | ⬜ 待验证 | 人工 |
| 副显示器 / 负坐标屏幕 | 🔶 已实现，待实机验证 | PanelPositioner 几何有单元测试；UI 测试在该几何下按环境守卫跳过 |
| 菜单栏自动隐藏 | ⬜ 待验证 | 人工 |
| 刘海屏（visibleFrame 收敛）| ⬜ 待验证 | 人工 |
| 快速连击状态项（状态机幂等）| ✅ 通过 | XCUITest toggle 重试循环 + PanelVisibilityStateMachineTests |
| 点击外部关闭且无监视器残留 | 🔶 已实现，待实机验证 | 失活关闭路径经窗口服务器诊断人工验证（orderOut 后 onscreen=false） |

> 注意：UI 测试会按 accessibility label 匹配状态项，运行前请关闭其他
> Calenda 实例（测试 setUp 已自动清理同名进程并等待退出）。锁屏、
> Secure Input 被输入法工具持有、或副屏位于主屏上方时，受影响的
> 用例会以明确原因跳过而非误报失败。
