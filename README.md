# Calenda

仅驻留在 macOS 菜单栏的原生日历工具：公历月历、农历、节气、中国法定节假日与天气（规划中）。
设计方案见 [DESIGN.md](DESIGN.md)。

## 系统要求

- macOS 26+
- Xcode 26+（稳定版，含 macOS 26 SDK）

## 构建与测试

```bash
xcodebuild -project Calenda.xcodeproj -scheme Calenda \
  -configuration Debug -destination 'platform=macOS' build

xcodebuild -project Calenda.xcodeproj -scheme Calenda \
  -destination 'platform=macOS' test
```

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
