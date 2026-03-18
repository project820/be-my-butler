# BMB v0.3.5 — Repo Cleanup & Dead File Removal

## Problem Statement

repo에 중복 파일, 구버전 잔재, 참조 안 되는 파일이 모두 커밋/푸시되고 있음.
98개 tracked 파일 중 약 23개(src/ 전체)가 중복 또는 미사용.

## 현재 구조 분석 (2026-03-13)

### 중복 발견

| 위치 | 중복 대상 | 파일 수 | 상태 |
|------|----------|---------|------|
| `src/agents/` | `agents/` | 9개 | **완전 동일** — 같은 파일이 두 곳에 존재 |
| `src/scripts/` | `bmb-system/scripts/` | 6개 | **부분 동일** — bmb-system/에 v0.3.4 신규 파일 추가됨, src/는 구버전 |
| `src/config/` | `bmb-system/config/` | 1개 | **구버전** — src/config/defaults.json에 v0.3.4 키 없음 |
| `src/skills/be-my-butler/` | `skills/bmb/` | 2개 | **구 이름** — be-my-butler → bmb로 리네임됨. 구버전 잔재 |
| `src/skills/bmb-brainstorm/` | `skills/bmb-brainstorm/` | 1개 | **동일** |
| `src/skills/bmb-refactoring/` | `skills/bmb-refactoring/` | 1개 | **동일** |
| `src/skills/bmb-setup/` | `skills/bmb-setup/` | 1개 | **동일** |
| `src/templates/` | — | 2개 | **미사용** — handoff-frontmatter.md, session-prep.md는 코드에서 미참조 |

### 역할 정리

```
src/          → install.sh의 source directory (외부 사용자 설치용)
agents/       → ~/.claude/agents/로 symlink됨 (개발 중 직접 사용)
skills/       → ~/.claude/skills/로 symlink됨 (개발 중 직접 사용)
bmb-system/   → ~/.claude/bmb-system/으로 symlink됨 (런타임 경로)
```

**문제**: `src/`는 install.sh가 GitHub에서 다운로드 후 배포하는 용도인데,
개발 과정에서 `agents/`, `skills/`, `bmb-system/`이 직접 수정되면 `src/`는 동기화 안 됨.
결과: src/는 항상 구버전, 실제 코드와 불일치.

## 수정 설계

### Option A: src/ 제거, install.sh를 현재 구조 직접 참조 (Recommended)

```
repo/
├── agents/           ← install source (agents)
├── skills/           ← install source (skills)
├── bmb-system/       ← install source (scripts, config, bin)
│   ├── scripts/
│   ├── config/
│   ├── bin/
│   └── plans/        ← .gitignore or keep for reference
├── docs/
├── install.sh        ← 수정: src/ 대신 agents/, skills/, bmb-system/ 직접 참조
└── (src/ 삭제)
```

**install.sh 수정**:
- `SRC_DIR` 개념 제거
- `skills/be-my-butler/` 참조 → `skills/bmb/` 로 변경
- `src/scripts/` → `bmb-system/scripts/`
- `src/config/` → `bmb-system/config/`
- `src/agents/` → `agents/`
- `src/templates/` 참조 제거 (필요시 bmb-system/templates/로 이동)

**장점**: 단일 진실의 원천 (single source of truth). 수정하면 즉시 install에도 반영.
**단점**: install.sh 경로 전면 수정 필요.

### Option B: src/를 symlink으로 유지

```
src/agents → ../agents
src/skills → ../skills
src/scripts → ../bmb-system/scripts
src/config → ../bmb-system/config
```

**장점**: install.sh 수정 최소화.
**단점**: git은 symlink을 잘 추적하지만, GitHub download (tar.gz)에서 symlink이 깨질 수 있음. 외부 사용자 설치 실패 위험.

### 선택: Option A

## 삭제 대상 파일 (23개)

```
src/agents/bmb-analyst.md
src/agents/bmb-architect.md
src/agents/bmb-consultant.md
src/agents/bmb-executor.md
src/agents/bmb-frontend.md
src/agents/bmb-simplifier.md
src/agents/bmb-tester.md
src/agents/bmb-verifier.md
src/agents/bmb-writer.md
src/config/defaults.json
src/scripts/bmb-analytics.sh
src/scripts/bmb-learn.sh
src/scripts/conversation-logger.py
src/scripts/cross-model-run.sh
src/scripts/knowledge-index.sh
src/scripts/knowledge-search.sh
src/skills/be-my-butler/SKILL.md
src/skills/be-my-butler/bmb.md
src/skills/bmb-brainstorm/SKILL.md
src/skills/bmb-refactoring/SKILL.md
src/skills/bmb-setup/SKILL.md
src/templates/handoff-frontmatter.md
src/templates/session-prep.md
```

## 이동 대상 (src/에만 있는 파일)

| 파일 | 현재 | 이동 위치 |
|------|------|----------|
| `src/scripts/conversation-logger.py` | src/에만 존재 | `bmb-system/scripts/conversation-logger.py` |
| `src/templates/session-prep.md` | src/에만 존재 | 삭제 또는 `bmb-system/templates/` (사용 여부 확인 필요) |
| `src/templates/handoff-frontmatter.md` | src/에만 존재 | 삭제 또는 `bmb-system/templates/` (사용 여부 확인 필요) |

## 추가 정리 대상

| 파일/폴더 | 이유 | 액션 |
|-----------|------|------|
| `skills/bmb/SKILL.md` | `skills/bmb/bmb.md`와 역할 중복? 확인 필요 | 확인 후 결정 |
| `bmb-system/plans/` | 계획 문서 — 구현 완료된 것은 아카이브? | .gitignore 또는 유지 |
| `.bmb/` | 런타임 디렉토리 — .gitignore에 있는지 확인 | .gitignore 확인 |
| `examples/demo-todo-app/` | 데모앱 — 필요한지 확인 | 유저 확인 |

## 수정 대상 파일

| 파일 | 변경 |
|------|------|
| `install.sh` | src/ 참조 → agents/, skills/, bmb-system/ 직접 참조. be-my-butler → bmb 경로 변경 |
| `uninstall.sh` | src/ 참조 있으면 제거 |
| `doctor.sh` | src/ 참조 있으면 제거 |
| `.gitignore` | src/ 관련 항목 정리, .bmb/ 확인 |
| `docs/architecture.md` | 디렉토리 구조 설명 업데이트 |
| `README.md` | 프로젝트 구조 섹션 업데이트 |
| `CONTRIBUTING.md` | 개발 가이드 경로 업데이트 |

## .gitignore 점검

```
# 확인 필요 항목
.bmb/               ← 런타임 데이터, 반드시 ignore
*.partial            ← codex 부분 출력
*.tmp.*              ← temp files
bmb-system/runtime/  ← NDJSON spool 등
```

## 검증 기준

- [ ] `git ls-files src/` → 0개
- [ ] `install.sh` 로컬 설치 테스트 성공
- [ ] `install.sh` GitHub tar.gz 설치 테스트 성공 (선택)
- [ ] 모든 agent/skill/script 경로가 일관됨
- [ ] `.bmb/`가 .gitignore에 포함
- [ ] 총 tracked 파일 수 98 → ~75 (약 23개 감소)

## .gitignore 전면 정비

### 현재 문제
- **화이트리스트 방식** (`*` + `!`)을 사용하지만, `!src/` `!src/**`로 src/ 전체가 열려있음
- `bmb-system/.bmb/`가 bmb-system/.gitignore에서만 무시 → 루트 `.bmb/`는 규칙 없음
- `runtime/`, `*.partial`, `*.tmp.*` 등 v0.3.4 런타임 산출물 규칙 없음

### 정비 후 .gitignore

```gitignore
# Whitelist: only track be-my-butler project files
*

# Project infrastructure
!.gitignore
!.markdownlint.json
!.github/
!.github/**
!LICENSE
!README.md
!VERSION
!CHANGELOG.md
!CONTRIBUTING.md
!WHATS-NEW-*.md
!install.sh
!uninstall.sh
!doctor.sh

# Agents (BMB only)
!agents/
!agents/bmb-*.md

# Skills (BMB only)
!skills/
!skills/bmb/
!skills/bmb/**
!skills/bmb-brainstorm/
!skills/bmb-brainstorm/**
!skills/bmb-setup/
!skills/bmb-setup/**
!skills/bmb-status/
!skills/bmb-status/**
!skills/bmb-refactoring/
!skills/bmb-refactoring/**

# BMB system (scripts, config, bin, plans)
!bmb-system/
!bmb-system/**

# Tests, docs, examples
!tests/
!tests/**
!docs/
!docs/**
!examples/
!examples/**

# ─── Explicitly IGNORE (runtime, temp, secrets) ───

# BMB runtime data (NEVER commit)
.bmb/
bmb-system/runtime/
bmb-system/.bmb/

# Temp/partial files from codex shim
*.partial
*.tmp.*

# OS artifacts
.DS_Store
Thumbs.db

# Python
__pycache__/
*.pyc

# Editor
*.swp
*.swo
*~

# Environment / secrets
.env
.env.*
!.env.example
```

### 삭제 항목
- `!src/` `!src/**` 제거 (src/ 디렉토리 자체를 삭제하므로)
- bmb-system/.gitignore → 루트 .gitignore에 통합 후 삭제

## 핵심 제약

- src/ 삭제 전 conversation-logger.py 등 src/에만 있는 파일을 먼저 이동
- install.sh는 외부 사용자가 사용 → GitHub에서 tar.gz 다운로드 후 설치 가능해야 함
- 삭제는 한 커밋에서 atomic하게 수행 (중간 상태에서 install.sh가 깨지지 않도록)
- .gitignore 정비는 src/ 삭제와 같은 커밋에서 수행
