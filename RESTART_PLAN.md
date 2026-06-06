# Translayr 重启方案（划词翻译版）

> 决策：核心交互改为**划词翻译**；翻译后端**本地 Ollama + 云端可选**；本文为动代码前的方案，待确认。
> 日期：2026-06-06

---

## 0. 已确认决策（2026-06-06）
1. 云端 provider：**OpenAI 兼容**（base URL + key + model，可指向官方/中转/本地兼容端点）。
2. Rewrite 默认：**改写后直接原地替换**（靠系统撤销兜底），预览为可选项。
3. 形态：**纯菜单栏**（移除主 Window，App 只在菜单栏 + 弹窗）。
4. 范围：**先做纯翻译**，不做润色/风格（预留接口）。

---

## 1. 目标与定位

把 Translayr 从「系统级 inline 下划线」重启为「**系统级翻译 + 输入改写**」工具，包含两个模式：

- **读·划词翻译（Read）**：在任何 app 选中文字 → 快捷键/划词图标/自动 → 选区旁弹出译文 → 复制/替换/钉住。
- **写·输入改写直发（Rewrite）**：在任意输入框用母语打字（如中文）→ 一键把当前输入框/选区文本改写成目标语言（英文）并**原地替换**，随后用户直接回车发送。

> Rewrite 是核心差异点：让"用母语想、用外语发"变成一个快捷键的事。这正是旧版"点下划线替换原文"想做但没做对的方向。

定位差异化（对标 Bob / Easydict —— 它们基本只做"读"）：
- **读+写双模式**，Rewrite 是独有卖点。
- **极致可靠**：用「AX 取词 + 模拟复制兜底」，覆盖几乎所有 app（含 Electron / 浏览器 / 自绘）。
- **本地优先可选云端**：隐私模式走 Ollama，速度模式走云端，可插拔。
- **轻、快、克制**：快捷键触发，不满屏画线。

放弃：满屏下划线、按窗口事件频繁隐藏/重画、对 `kAXBoundsForRangeParameterizedAttribute` 的强依赖。

---

## 1.5 两个模式的差异（共用底座，触发与产出不同）

| | 读·划词翻译 (Read) | 写·输入改写 (Rewrite) |
|---|---|---|
| 取什么 | 选中的文字（必有选区） | **优先选区**；无选区则取**整个输入框** `kAXValue` |
| 触发 | 快捷键 / 划词小图标 / 自动弹窗 | 独立快捷键（如 ⌥↩）；可选"改写后弹确认" |
| 产出 | 弹窗显示译文（不改原文） | **原地替换**原文 → 用户直接发送 |
| 替换方式 | 用户点"替换"才写回 | 合成粘贴写回（保留撤销栈），可设"改写即替换"或"先预览再替换" |
| 方向 | 外语→母语（读不懂的） | 母语→外语（要发出去的） |

两模式共用 `SelectionCapture` + `TranslationProvider` + 缓存，仅 `TriggerController` 与"产出动作"不同。

---

## 2. 新架构

```
TranslayrApp
├── Core/
│   ├── SelectionCapture.swift     // 取词：AX kAXSelectedText + 模拟⌘C兜底 + 还原剪贴板
│   ├── HotkeyCenter.swift         // 全局快捷键（复用 GlobalShortcutCenter），读/写各一组
│   ├── TriggerController.swift    // 触发策略：快捷键 / 划词小图标 / 自动 → 分发到 Read/Rewrite
│   ├── TextReplacer.swift         // 原地替换：合成粘贴（选区⌘V / 整框⌘A+⌘V）+ 还原剪贴板
│   └── PopupPositioner.swift      // 选区/鼠标定位 + 坐标转换（复用现有换算+多屏逻辑）
├── Translation/
│   ├── TranslationProvider.swift  // protocol（统一接口，支持流式）
│   ├── OllamaProvider.swift       // 本地，复用现有 Ollama 集成
│   ├── CloudProvider.swift        // 云端：OpenAI 兼容 / Claude / DeepL（先做1个）
│   ├── TranslationService.swift   // 路由 + 缓存 + 取消 + 语言判定
│   └── TranslationCache.swift     // LRU 缓存（源文+方向+provider 为 key）
├── UI/
│   ├── TranslationPopup.swift     // SwiftUI 弹窗（复用现有 TranslationPopupView 重构）
│   ├── SelectionIconWindow.swift  // 划词后选区旁的小图标
│   ├── MenuBarView.swift          // 复用
│   └── Settings/                  // 重做面板（见 §6）
├── Config/
│   ├── AppSettings.swift          // 统一设置（替代散落的 UserDefaults 读写）
│   ├── LanguageConfig.swift       // 保留（语言枚举+方向）
│   └── ProviderConfig.swift       // 后端选择+密钥+模型
└── Support/                       // Logger / UpdateChecker / SystemServiceProvider / Telemetry（保留）
```

### 取词核心（最关键、决定可靠性）
`SelectionCapture` 两级策略：
1. **优先 AX**：取 frontmost app 的 focused element，读 `kAXSelectedTextAttribute`。原生控件直接拿到，无副作用。
2. **兜底模拟复制**（Easydict 同款思路，覆盖所有 app）：
   - 暂存当前剪贴板内容（含类型）；
   - 合成 `⌘C`（`CGEvent`）；短暂等待；
   - 读 `NSPasteboard.general` 的字符串；
   - **还原**原剪贴板，避免污染。
3. 两者都空 → 不弹窗（或提示"未选中文字"）。

> 这一步替换掉旧 `AccessibilityMonitor` 的 2 秒轮询 + 全局文本读取，是体验提升的核心。

### 定位
- 优先用 `kAXSelectedTextRangeAttribute` + `kAXBoundsForRange` 拿选区屏幕矩形（拿得到就贴着选区弹）；
- 拿不到就回退到**鼠标位置**弹窗（永远有兜底，不会"不出现"）。
- 复用现有多屏坐标换算（`OverlayWindow.swift:310-323` 的逻辑搬到 `PopupPositioner`）。

### 翻译后端抽象
```swift
protocol TranslationProvider {
    var id: String { get }
    func translate(_ text: String,
                   from: Language?, to: Language,
                   stream: Bool) -> AsyncThrowingStream<String, Error>
}
```
- `OllamaProvider`：复用现有 `LocalModelClient` 的 Ollama 流式调用。
- `CloudProvider`：先实现 **OpenAI 兼容 / Claude** 之一（流式），DeepL 可后补。
- `TranslationService`：根据 `ProviderConfig` 选 provider；命中 `TranslationCache` 直接返回；负责取消上一个未完成请求；做源语言自动判定（`NSLinguisticTagger` 或现有正则）决定翻译方向。

---

## 3. 保留 / 删除清单

**保留并复用**
- `scripts/`（签名/公证/版本）、`BUILD_RELEASE.md` 等发布链路
- `GlobalShortcutCenter.swift`（全局快捷键）
- `UpdateChecker.swift`、`SystemServiceProvider.swift`、Sentry/TelemetryDeck
- `LanguageConfig.swift`（语言枚举/方向/prompt 模板）
- `OllamaConfig.swift` → 并入 `ProviderConfig`
- `TranslationPopupView`（重构复用）+ 现有坐标换算知识
- 设置面板的壳（`SettingsView` 结构）

**删除 / 退役（旧 inline 覆盖层与拼写检查残留）**
- `AccessibilityMonitor.swift`（轮询、全局读文本、窗口追踪、bounds heuristic）→ 拆出有用部分后删
- `SpellCheckMonitor.swift`（满屏检测逻辑）
- `OverlayWindow.swift` 的 `UnderlineView` + 每条线 0.1s Timer 的 hover 轮询
- `SpellService.swift`、`Protocols/SpellAnalyzing.swift`、`Models/Suggestion.swift`（拼写检查时代死代码）
- 对应测试：`SpellServiceTests`、`SuggestionTests`（`LocalModelClientTests` 改造保留）
- 全局 `print` 日志 → 统一 `Logger`（仅 Debug 输出）

---

## 4. 里程碑（建议按此顺序提交）

| 阶段 | 内容 | 验收 |
|---|---|---|
| **M0 清理脚手架** | 删死代码、建新目录结构、加 `Logger`/`AppSettings`、保编译通过 | App 能启动、菜单栏在 |
| **M1 读·取词闭环** | 快捷键 → `SelectionCapture`(AX+复制兜底) → 弹窗 → Ollama 流式翻译 | 在 Safari/Notes/Chrome/VSCode 选词都能翻译 |
| **M2 写·改写直发** | 独立快捷键 → 取选区/整框 → 翻译 → `TextReplacer` 原地替换 | 在 Slack/邮件/微信网页输入中文，一键变英文待发，撤销可还原 |
| **M3 后端抽象** | `TranslationProvider` 协议 + `CloudProvider`(1个) + 缓存 + 取消 | 设置里切本地/云端，缓存命中秒回 |
| **M4 触发与操作** | 划词小图标 + 自动模式 + 选区精确定位；复制/替换/钉住；改写预览态 | 三种触发顺手、定位贴合、改写可"先看后替换" |
| **M5 设置面板** | 重做面板（读/写快捷键、后端/密钥、语言含自动检测、自动模式、skip 列表） | 设置项齐全可用 |
| **M6 打磨发布** | 错误态/空态、首次权限引导、多语言、性能、走签名公证出 dmg | 端到端可发布 |

---

## 5. 关键技术取舍（相对旧版的修复）

| 旧问题 | 新做法 |
|---|---|
| 2s 轮询取文本，延迟大 | 事件驱动：快捷键/划词即时取词 |
| 强依赖 AX bounds，多数 app 不支持 | 取词用「AX+模拟复制兜底」；定位拿不到选区就回退鼠标位置 |
| 每条线一个 0.1s Timer 轮询 hover | 单一弹窗，正常 NSEvent，无轮询 |
| 窗口移动/滚动频繁隐藏重画 | 划词翻译无常驻覆盖层，问题消失 |
| 整体 setValue 替换文本，丢光标/撤销 | 替换走「合成粘贴」保留撤销栈 |
| 无缓存、每次 new client、冷启动慢 | `TranslationService` 持有长连 + LRU 缓存 + 云端可选提速 |
| 满屏 print | 统一 Logger，Release 静默 |

---

## 6. 设置面板（重做）
- **通用**：开机自启、触发方式（快捷键/划词图标/自动）、快捷键绑定
- **翻译**：源/目标语言（含"自动检测源语言"）、后端选择（本地 Ollama / 云端）
- **后端**：Ollama 地址+模型；云端 provider + API Key + 模型
- **排除**：skip app 列表（保留并复用）
- **关于/更新**：复用

---

## 7. 风险与待确认
1. **模拟复制兜底**会瞬时占用剪贴板（已设计还原），极少数 app 可能拦截合成事件——需实测覆盖率。
2. **云端 provider 先做哪个**：OpenAI 兼容 / Claude / DeepL —— 建议先 OpenAI 兼容（最通用），待定。
3. **Rewrite 替换策略**：默认"改写即原地替换"（最快，靠撤销兜底）还是"先弹预览、确认再替换"（更稳）。倾向：默认即替换 + 设置可切预览。
4. **Rewrite 取词范围**：无选区时取整个输入框是否总是对的？多行编辑器里可能只想改一段——建议规则：有选区只改选区，无选区改整框。
5. **Rewrite 是否只做"翻译"还是也做"润色/改写风格"**（正式/口语）。先做纯翻译，预留风格选项。
6. 是否保留 App 主窗口，还是纯菜单栏 + 弹窗（更轻）。

---

## 8. 下一步
确认本方案后，从 **M0+M1** 开始：先把死代码清掉、立起取词最小闭环，让你能在真实 app 里试用「选词→翻译」的手感，再逐步推进 M2~M5。
