# Contributing to Calenda
感谢贡献。Calenda 是一个小型、原生、离线优先的 macOS 菜单栏应用；请优先提交可验证且范围明确的改动。
## Before opening a pull request
1. 阅读 README、PRIVACY.md、SECURITY.md 和 THIRD_PARTY_NOTICES.md。
2. 不要提交密钥、令牌、证书、provisioning profile、真实位置数据、DerivedData 或 Xcode 用户状态。
3. 新增网络能力、依赖或持久化前，请说明必要性，并保留离线降级路径。
4. 安全问题请遵循 SECURITY.md，不要公开创建 Issue 或 Pull Request。
## Local verification
使用 Xcode 27 beta 5 或更新版本，运行 README 中的串行单元测试命令。涉及 NSPanel、状态栏、设置界面或可见布局的改动，还需要在真实 macOS 应用中验证并保留截图或测试证据。
## Pull request expectations
说明用户可见行为、测试命令和结果。不要混入格式化、依赖升级或无关重构。修改第三方依赖、数据源或许可证时，同步更新 README、THIRD_PARTY_NOTICES.md 和相关测试。
## Contribution license
提交 Pull Request 即表示你有权提交该内容，并同意你的贡献按本仓库 MIT License 许可。

