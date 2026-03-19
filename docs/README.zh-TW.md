> Last synced with README.md: 2026-03-19

[English](../README.md) | [한국어](README.ko.md) | [日本語](README.ja.md) | **繁體中文**

# BMB — Be My Butler

**Claude Code 的 12 步驟、10 代理多代理編排管線**

讓一個代理包辦所有事情的時代結束了。
BMB 由 10 個專業代理自主協作，涵蓋設計、實作、驗證、分析到簡化的完整流程。

[![Version](https://img.shields.io/badge/version-0.4.0-blue.svg)](../CHANGELOG.md)
[![What's New](https://img.shields.io/badge/what's_new-v0.4.0-green.svg)](../WHATS-NEW-0.4.md)

---

## 為什麼選擇 BMB？

| 傳統工作流程 | BMB |
|---|---|
| 單一代理處理所有任務 | 10 個專業代理分工協作 |
| 自己寫的程式碼自己審查 | 跨模型盲審驗證 (Gemini) |
| 沒有設計直接開發 | Council 辯論 → 達成共識後才開工 |
| 在 main 分支直接作業 | Worktree 隔離，安全實驗 |
| 反覆犯同樣的錯誤 | 自動學習 → 下次 session 自動套用 |
| 缺少管線分析 | Analytics + Analyst 代理進行模式分析 |

---

## 快速開始

```bash
# 1. 安裝（1 分鐘）
curl -fsSL https://raw.githubusercontent.com/project820/be-my-butler/main/install.sh | bash

# 2. 專案初始化
/BMB-setup

# 3. 執行管線（在 tmux session 中）
/BMB
```

> **前置需求**：需要安裝 tmux。BMB 透過 tmux 來建立與管理代理。

---

## 核心功能

- **12 步驟完整管線** — Session Prep → Consulting → Council Debate → Architecture → Execution → Testing → Blind Verification → Simplification → **Analyst (Step 10.5)** → Documentation → Learning → Handoff
- **跨模型盲審驗證** — 實作代理完全不知情的狀態下，由 Gemini 獨立驗證，消除偏見
- **Council Debate** — Lead + Consultant + 外部模型針對設計方案進行辯論，找出最佳方案
- **Worktree 隔離** — 使用 `git worktree` 不碰 main 分支，安全地進行實驗
- **自動學習** — 每次 session 的經驗教訓自動記錄，在下次管線中發揮作用
- **Analytics + Analyst** — 將管線遙測數據記錄到 `analytics.db`，Analyst 代理進行 Bird's Law 嚴重性分類和模式晉升候選識別
- **Context7 即時文件** — Architect、Executor、Frontend 代理在撰寫程式碼前透過 Context7 MCP 查詢最新函式庫文件
- **Consultant Coordinator 模式** — Consultant 以使用者顧問 + 管線監控的雙通道模式運作

---

## 正確性優先的設計哲學

BMB 的核心理念是「正確性先於速度」。在 AI 輔助開發快速迭代的浪潮中，很容易為了追求速度而犧牲品質。BMB 透過多層驗證機制確保每一步都經得起考驗：

1. **Council Debate** — 動手之前先辯論，避免方向錯誤
2. **Blind Verification** — 獨立的第三方模型審查，不受實作者影響
3. **Simplification** — 專門的簡化代理確保程式碼不會過度工程
4. **Analyst** — 回顧分析識別反覆出現的模式，推動規則晉升

語言設定方式：

```jsonc
// .bmb/config.json
{
  "language": "zh-TW"
}
```

---

## 互動式架構指南

以視覺化方式瀏覽 12 步驟管線的完整流程：

**[docs/index.html](index.html)** — 基於 Mermaid 圖表的互動式指南

---

## 完整文件

架構深入分析、代理協議、跨模型設定、進階自訂等詳細內容，請參閱英文文件：

**[English README (Full Documentation)](../README.md)**

---

## 相關技能

| 技能 | 用途 |
|---|---|
| `/BMB` | 完整 12 步驟管線 |
| `/BMB-setup` | 專案初始設定 |
| `/BMB-brainstorm` | Lead + Consultant 諮詢 session |
| `/BMB-refactoring` | 跨模型審查的重構作業 |

---

## License

[MIT](../LICENSE)
