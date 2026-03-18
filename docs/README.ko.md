> Last synced with README.md: 2026-03-12

[English](../README.md) | **한국어** | [日本語](README.ja.md) | [繁體中文](README.zh-TW.md)

# BMB — Be My Butler

**Claude Code를 위한 11.5단계, 9-에이전트 멀티에이전트 오케스트레이션 파이프라인**

혼자서 코드를 작성하고, 혼자서 검증하고, 혼자서 리팩토링하는 시대는 끝났습니다.
BMB는 9개의 전문 에이전트가 설계-구현-검증-분석-간소화까지 자율적으로 협업하는 파이프라인입니다.

[![Version](https://img.shields.io/badge/version-0.2.0-blue.svg)](../CHANGELOG.md)
[![What's New](https://img.shields.io/badge/what's_new-v0.2-green.svg)](../WHATS-NEW-0.2.md)

---

## 왜 BMB인가?

| 기존 워크플로우 | BMB |
|---|---|
| 한 에이전트가 모든 걸 처리 | 9개 전문 에이전트가 역할 분담 |
| 본인이 작성한 코드를 본인이 검증 | 크로스 모델 블라인드 검증 (Gemini) |
| 설계 없이 바로 구현 | Council 토론 → 합의 후 착수 |
| 메인 브랜치에서 직접 작업 | Worktree 격리로 안전한 실험 |
| 매번 같은 실수 반복 | 자동 학습 → 다음 세션에 반영 |
| 파이프라인 분석 없음 | Analytics + Analyst 에이전트가 패턴 분석 |

---

## 빠른 시작

```bash
# 1. 설치 (1분)
curl -fsSL https://raw.githubusercontent.com/project820/be-my-butler/main/install.sh | bash

# 2. 프로젝트 초기화
/BMB-setup

# 3. 파이프라인 실행 (tmux 세션 안에서)
/BMB
```

> **필수 조건**: tmux가 설치되어 있어야 합니다. BMB는 tmux 기반으로 에이전트를 생성하고 관리합니다.

---

## 핵심 기능

- **11.5단계 풀 파이프라인** — Session Prep → Consulting → Council Debate → Architecture → Execution → Testing → Blind Verification → Simplification → **Analyst (Step 10.5)** → Documentation → Learning → Handoff
- **크로스 모델 블라인드 검증** — 구현 에이전트가 모르는 상태에서 Gemini가 독립 검증, 편향 제거
- **Council Debate** — Lead + Consultant + 외부 모델이 설계를 놓고 토론, 최선의 접근법 도출
- **Worktree 격리** — `git worktree`로 메인 브랜치를 건드리지 않고 안전하게 작업
- **자동 학습** — 매 세션의 실수와 개선점이 자동으로 기록되어 다음 파이프라인에 반영
- **Analytics + Analyst** — `analytics.db`에 파이프라인 텔레메트리 기록, Analyst 에이전트가 Bird's Law 심각도 분류 및 패턴 프로모션 후보 식별
- **Context7 라이브 문서** — Architect, Executor, Frontend 에이전트가 코드 작성 전 최신 라이브러리 문서를 Context7 MCP로 조회
- **Consultant Coordinator 모델** — Consultant가 사용자 어드바이저 + 파이프라인 모니터 듀얼 채널로 동작

---

## 한국어 네이티브 지원

BMB의 Consultant 에이전트는 한국어로 자연스럽게 소통합니다. `config.json`에서 언어를 설정하면 Consultant가 한국어로 설계 논의, 트레이드오프 설명, 의사결정 근거를 제공합니다.

```jsonc
// .bmb/config.json
{
  "language": "ko"
}
```

설정 후 `/BMB-brainstorm`을 실행하면, Consultant가 한국어로 프로젝트를 분석하고 설계 방향을 제안합니다. 기술적 맥락을 한국어로 바로 이해할 수 있어 의사결정 속도가 빨라집니다.

---

## 인터랙티브 아키텍처 가이드

11.5단계 파이프라인의 전체 흐름을 시각적으로 확인하세요:

**[docs/index.html](index.html)** — Mermaid 다이어그램 기반 인터랙티브 가이드

---

## 상세 문서

아키텍처 심층 분석, 에이전트 프로토콜, 크로스 모델 설정, 고급 커스터마이징 등은 영문 문서를 참고하세요:

**[English README (Full Documentation)](../README.md)**

---

## 관련 스킬

| 스킬 | 용도 |
|---|---|
| `/BMB` | 풀 11.5단계 파이프라인 |
| `/BMB-setup` | 프로젝트 초기 설정 |
| `/BMB-brainstorm` | Lead + Consultant 컨설팅 세션 |
| `/BMB-refactoring` | 크로스 모델 리뷰 기반 리팩토링 |

---

## License

[MIT](../LICENSE)
