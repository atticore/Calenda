# Third-Party Notices

Calenda 的代码以 [MIT License](LICENSE) 发布，同时包含或依赖下列第三方代码与数据。
分发本软件（源代码或二进制）时，请一并保留本文件。

## Tyme4Swift — 农历 / 节气计算

- 上游：<https://github.com/6tail/tyme4swift>（作者 6tail），本项目锁定 v1.5.0，经 Swift Package Manager 引入。
- 用途：农历日期、农历节日与二十四节气计算；仅在上游适配层 `Calenda/Infrastructure/TymeLunarAdapter.swift` 内部使用，不向应用其余部分暴露第三方类型。
- 许可：MIT

```
MIT License

Copyright (c) 6tail

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## holiday-cn — 中国法定节假日数据

- 上游：<https://github.com/NateScarlet/holiday-cn>（作者 NateScarlet）。
- 用途：法定节假日与调休安排。安装包内置 `Calenda/Resources/Holidays/2025.json`、`2026.json` 快照；运行时经固定镜像链（cdn.jsdelivr.net、fastly.jsdelivr.net、raw.githubusercontent.com）检查与应用内固定提交和 SHA-256 一致的内容。
- 数据出处：上游项目自动抓取国务院办公厅历年放假公告整理而成，每年数据文件的 `papers` 字段附公告原文链接，数据内容以公告为准。
- 许可：MIT

```
MIT License

Copyright (c) 2019 NateScarlet

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Open-Meteo — 当前天气与城市搜索

- 服务：<https://open-meteo.com/>
  - Forecast API：`api.open-meteo.com/v1/forecast`
  - Geocoding API：`geocoding-api.open-meteo.com/v1/search`
- 用途：当前天气（温度、体感温度、WMO 天气代码、昼夜标志）与手动选城时的城市搜索（中文结果）。Calenda 不使用 API Key，走匿名免费档。
- 条款与署名：按 [Open-Meteo Terms of Use](https://open-meteo.com/en/terms)，通过 API 获得的数据以 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) 提供，须注明出处 —— Weather data by [Open-Meteo.com](https://open-meteo.com/)。
- **限制**：Open-Meteo 免费档仅限非商业用途；商业用途需要购买其付费订阅。若基于 Calenda 分发商业版本，请自行替换天气提供商或购买商业配额。

---

本文件描述的第三方权利与许可以上游仓库与服务条款的当前版本为准；若上游许可变更，请以对应项目自行发布的声明为依据。
