# Release Checklist
此清单定义首次公开发布前和每个 Release 前应完成的检查；完成前不要将仓库或构建产物标记为公开发布。
## Repository and history
- 确认 git log --all 的公开身份仅包含已批准的姓名和邮箱。
- 从干净 clone 构建和发布；不要使用 git push --mirror 推送包含旧对象的仓库。
- 检查所有分支、标签和待发布补丁，不含密钥、令牌、证书、provisioning profile、私有 URL 或个人数据。
- 确认本地 Git 提交身份为 hchenww@gmail.com。
## Security and privacy
- 运行 secret scan，并处理所有命中或形成经过审查的最小允许项。
- 检查 README.md、PRIVACY.md、系统定位用途说明与当前代码的数据流一致。
- 验证用户主动定位、城市搜索、天气、节假日网络失败和缓存清理的行为仍符合说明。
- 检查 SECURITY.md 中的联系地址可正常收件；如启用 GitHub 私密漏洞报告，同步更新文档。
## Dependencies and data
- 核对 Package.resolved、README.md 与 THIRD_PARTY_NOTICES.md 的版本和许可。
- 对每个 holiday-cn 年度文件确认固定 commit、原始 SHA-256 和内置快照一致。
- 验证错误哈希、错误来源 URL、结构错误载荷和旧缓存不会覆盖内置或最后有效数据。
- 复核 Open-Meteo 条款、署名和非商业限制是否仍适用。
## Build and release evidence
- 在隔离的 DerivedData 目录运行串行单元测试。
- 运行 Debug 构建并审查编译器诊断。
- 对界面改动完成真实应用验证；涉及面板几何时保存最终截图。
- 完成新的全量安全扫描，处理或接受所有发现。
- 如分发签名应用，验证签名、公证、staple 和 spctl 结果，并记录构建产物 SHA-256。

