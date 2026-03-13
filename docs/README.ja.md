> Last synced with README.md: 2026-03-12

[English](../README.md) | [한국어](README.ko.md) | **日本語** | [繁體中文](README.zh-TW.md)

# BMB — Be My Butler

**Claude Codeのための11.5ステップ・9エージェント・マルチエージェント・オーケストレーションパイプライン**

一人のエージェントにすべてを任せる時代は終わりました。
BMBは9つの専門エージェントが設計・実装・検証・分析・簡素化まで自律的に協調するパイプラインです。

[![Version](https://img.shields.io/badge/version-0.2.0-blue.svg)](../CHANGELOG.md)
[![What's New](https://img.shields.io/badge/what's_new-v0.2-green.svg)](../WHATS-NEW-0.2.md)

---

## なぜBMBなのか？

| 従来のワークフロー | BMB |
|---|---|
| 1エージェントで全処理 | 9つの専門エージェントが役割分担 |
| 自分が書いたコードを自分で検証 | クロスモデル・ブラインド検証 (Gemini) |
| 設計なしで即実装 | Council討論 → 合意後に着手 |
| mainブランチで直接作業 | Worktree分離で安全な実験 |
| 同じミスを繰り返す | 自動学習 → 次のセッションに反映 |
| パイプライン分析なし | Analytics + Analystエージェントがパターン分析 |

---

## クイックスタート

```bash
# 1. インストール（1分）
curl -fsSL https://raw.githubusercontent.com/project820/be-my-butler/main/install.sh | bash

# 2. プロジェクト初期化
/BMB-setup

# 3. パイプライン実行（tmuxセッション内で）
/BMB
```

> **前提条件**: tmuxが必要です。BMBはtmuxベースでエージェントの生成・管理を行います。

---

## 主な機能

- **11.5ステップ・フルパイプライン** — Session Prep → Consulting → Council Debate → Architecture → Execution → Testing → Blind Verification → Simplification → **Analyst (Step 10.5)** → Documentation → Learning → Handoff
- **クロスモデル・ブラインド検証** — 実装エージェントが知らない状態でGeminiが独立検証、バイアスを排除
- **Council Debate** — Lead + Consultant + 外部モデルが設計を議論し、最善のアプローチを導出
- **Worktree分離** — `git worktree`でmainブランチに触れず安全に作業
- **自動学習** — 各セッションの教訓が自動記録され、次のパイプラインに反映
- **Analytics + Analyst** — `analytics.db`にパイプラインテレメトリを記録、AnalystエージェントがBird's Law重大度分類とパターンプロモーション候補を特定
- **Context7ライブドキュメント** — Architect、Executor、Frontendエージェントがコード作成前にContext7 MCPで最新ライブラリドキュメントを参照
- **Consultant Coordinatorモデル** — Consultantがユーザーアドバイザー + パイプラインモニターのデュアルチャネルで動作

---

## tmuxワークフローとの親和性

BMBはtmuxをネイティブに活用します。Leadエージェントが上ペイン、Consultantが下ペインに常駐し、その他のエージェント（Architect、Executor、Testerなど）は必要に応じて`tmux split-pane`で生成され、タスク完了後に自動終了します。

```
┌──────────────────────────────┐
│         LEAD (上)             │
├──────────────────────────────┤
│      CONSULTANT (下)          │
└──────────────────────────────┘
  ↕ 必要に応じてペインを動的生成・破棄
```

日本のClaude Code開発者コミュニティでは、tmuxベースのワークフローが広く採用されています。BMBはこの文化と自然に統合され、既存の開発環境を変更せずにマルチエージェント協調を導入できます。

言語設定は`config.json`で指定します：

```jsonc
// .bmb/config.json
{
  "language": "ja"
}
```

---

## インタラクティブ・アーキテクチャガイド

11.5ステップの全体フローを視覚的に確認できます：

**[docs/index.html](index.html)** — Mermaidダイアグラムによるインタラクティブガイド

---

## 詳細ドキュメント

アーキテクチャの詳細分析、エージェントプロトコル、クロスモデル設定、カスタマイズ方法などは英語ドキュメントを参照してください：

**[English README (Full Documentation)](../README.md)**

---

## 関連スキル

| スキル | 用途 |
|---|---|
| `/BMB` | フル11.5ステップパイプライン |
| `/BMB-setup` | プロジェクト初期設定 |
| `/BMB-brainstorm` | Lead + Consultantコンサルティングセッション |
| `/BMB-refactoring` | クロスモデルレビュー基盤リファクタリング |

---

## License

[MIT](../LICENSE)
