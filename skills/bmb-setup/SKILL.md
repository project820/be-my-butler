---
name: bmb-setup
description: "BMB setup — first-time onboarding with 30Q user profiling, persona selection, and project configuration."
---

# /BMB-setup

One-stop setup for BMB. Handles prerequisites, user profiling, consultant persona, and project config.

## Process

### First-time Detection
```bash
source "$HOME/.claude/bmb-system/scripts/bmb-config.sh"
IS_FIRST_TIME=false
if ! bmb_config_check_setup; then IS_FIRST_TIME=true; fi
```

If `IS_FIRST_TIME=true`, show welcome message and explain the full onboarding process.
If re-running setup, show current values and allow selective updates.

### Step 0: Prerequisites Check
Run all checks first, report results as a table:

```bash
# 1. Claude Code CLI
command -v claude && claude --version

# 2. Cross-model CLIs (optional)
command -v codex && echo "codex: OK" || echo "codex: not found"
command -v gemini && echo "gemini: OK" || echo "gemini: not found"

# 3. Required env vars for optional features
[ -n "${BMB_TG_TOKEN:-}" ] && echo "BMB_TG_TOKEN: set" || echo "BMB_TG_TOKEN: not set"
[ -n "${BMB_TG_CHAT:-}" ] && echo "BMB_TG_CHAT: set" || echo "BMB_TG_CHAT: not set"

# 4. BMB system files
[ -d ~/.claude/bmb-system ] && echo "bmb-system: OK" || echo "bmb-system: MISSING"
[ -d ~/.claude/agents ] && ls ~/.claude/agents/bmb-*.md 2>/dev/null | wc -l | xargs -I{} echo "bmb agents: {} found"
```

Display results as:
| Component | Status | Required |
|-----------|--------|----------|
| Claude Code | vX.X.X | Yes |
| codex CLI | OK / missing | No (cross-model) |
| gemini CLI | OK / missing | No (cross-model) |
| BMB_TG_TOKEN | set / not set | No (notifications) |
| BMB_TG_CHAT | set / not set | No (notifications) |
| bmb-system/ | OK / MISSING | Yes |
| bmb agents | N found | Yes |

If required components are missing, stop and guide user to install them.

### Step 1: Check Existing Config
Read `.bmb/config.json` if it exists. Show current values to user. If no config exists, will create from defaults.

### Step 2: Interactive Configuration
Ask the user about each setting (show current/default value, accept Enter for no change):

1. **Git push policy**: yes / no / ask-each-time (default: ask)
2. **Git auto-commit**: true / false (default: true)
3. **Cross-model provider**: codex / gemini / none (default: codex)
   - If the selected provider CLI was not found in Step 0, warn and suggest `none`
4. **Cross-model timeout**: seconds (default: 3600)
5. **Claude agent timeout**: seconds (default: 1200)
6. **Writer timeout**: seconds (default: 600)
7. **Consultant style**: default / custom
   - If custom: ask for description (e.g., "explain like I'm a high schooler", "use construction analogies")
8. **Telegram notifications**: enabled / disabled (default: disabled)
   - If enabled but env vars missing from Step 0: warn that `BMB_TG_TOKEN` and `BMB_TG_CHAT` must be set in `~/.zshenv`
   - NEVER store tokens or chat IDs in config.json

### Phase B: User Profiling (first-time only, or on re-run if user requests)

~30 conversational questions in 5 sections. Present 2-3 questions at a time via AskUserQuestion. Allow skipping with sensible defaults.

**Section 1: Background & Role** (6 questions)
1. "어떤 분야에서 일하고 계세요?" (자유 입력)
2. "주로 다루는 기술 스택은?" (자유 입력, 여러 개 가능)
3. "코딩 경험 수준은?" → none / beginner / intermediate / advanced
4. "현재 주로 관심 있는 개발 분야는?" (자유 입력)
5. "혼자 작업 vs 팀 작업 중 주로?" → solo / team / both
6. "일할 때 선호하는 OS/환경은?" → macOS / Linux / Windows / WSL

**Section 2: Communication Style** (6 questions)
1. "설명을 들을 때 비유를 좋아하시나요, 직접적인 설명을 선호하시나요?" → analogy / direct / mixed
2. "간결한 답변 vs 상세한 답변?" → concise / balanced / detailed
3. "기술 용어를 그대로 쓸까요, 풀어서 설명할까요?" → as-is / explain / mix
4. "코드 예시를 많이 보여줄까요?" → yes / moderate / minimal
5. "영어/한국어 용어 선호?" → korean / english / mixed
6. "실수했을 때 어떻게 알려드릴까요?" → direct / gentle / humorous

**Section 3: Personality & MBTI** (6 questions)
1. "MBTI를 아시면 알려주세요 (선택사항)" → MBTI type or skip
2. "새로운 기능을 만들 때 큰 그림부터 vs 세부 사항부터?" → big-picture / detail-first
3. "결정을 내릴 때 데이터 vs 직감?" → data / intuition / both
4. "작업 스타일: 계획적 vs 유연?" → planned / flexible
5. "스트레스 받을 때 선호하는 소통 방식?" → minimal / supportive / humor
6. "피드백 스타일: 칭찬 위주 vs 개선점 위주?" → praise / improvement / balanced

**Section 4: Work Preferences** (6 questions)
1. "이상적인 작업 흐름은?" (자유 기술)
2. "코드 리뷰에서 가장 중요하게 보는 것?" → correctness / readability / performance / security
3. "문서화 스타일?" → minimal / moderate / thorough
4. "테스트 철학?" → tdd / test-after / minimal / depends
5. "리팩토링 빈도?" → frequently / only-when-needed / rarely
6. "자동화 선호 수준?" → maximum / moderate / manual-control

**Section 5: Interests & Goals** (6 questions)
1. "현재 배우고 싶은 기술?" (자유 입력)
2. "관심 도메인?" (복수 선택)
3. "AI를 어떻게 활용하고 싶으세요?" → productivity / learning / both
4. "프로젝트 규모 선호?" → small-focused / large-ambitious / varies
5. "오픈소스 참여?" → active / occasional / consumer
6. "장기 목표?" (자유 기술)

**Show progress**: "섹션 3/5 — 성격 & MBTI" 형태로 진행도 표시

### Phase C: Consultant Persona (after Phase B)

1. "AI 어시스턴트에게 이름을 지어줄 수 있어요. 원하시면 이름을 알려주세요 (선택)"
2. MBTI 기반 궁합 추천 (사용자 MBTI 입력 시):
   - 예: INTJ 사용자 → "분석적이고 체계적인 ENTJ 스타일 컨설턴트를 추천드려요"
   - 추천만 하고, 사용자가 다른 스타일 선택 가능
3. "컨설턴트 톤을 선택해주세요":
   - `friendly` — 친근하고 따뜻한 (기본)
   - `professional` — 격식 있고 정확한
   - `humorous` — 유머 섞인 가벼운
   - `academic` — 학술적이고 심도 있는
4. "설명 깊이를 선택해주세요":
   - `beginner` — 모든 것을 풀어서
   - `intermediate` — 핵심만 설명 (기본)
   - `advanced` — 전문가 수준으로 간결하게

### Phase D: Settings Scope

"지금 설정한 내용을 어디에 저장할까요?"
- **글로벌** (`~/.claude/bmb-profile.json`) — 모든 프로젝트에 적용 (기본)
- **이 프로젝트만** (`.bmb/config.json`) — 이 프로젝트에서만 적용
- **둘 다** — 글로벌 + 이 프로젝트에 동시 저장

### Step 3: Save Config

Write `~/.claude/bmb-profile.json` (if global or both):
```json
{
  "version": 1,
  "setup_complete": true,
  "setup_date": "2026-03-13",
  "user": {
    "background": "",
    "expertise_domains": [],
    "coding_experience": "intermediate",
    "work_style": "solo",
    "explanation_style": "mixed",
    "detail_level": "balanced",
    "jargon_preference": "mix",
    "code_examples": "moderate",
    "term_language": "mixed",
    "error_feedback": "direct",
    "mbti": null,
    "decision_style": "both",
    "planning_style": "flexible",
    "stress_comm": "supportive",
    "feedback_pref": "balanced",
    "language": "ko",
    "interests": [],
    "code_review_priority": "readability",
    "doc_style": "moderate",
    "test_philosophy": "test-after",
    "refactor_freq": "only-when-needed",
    "automation_level": "maximum"
  },
  "consultant_persona": {
    "name": null,
    "mbti": null,
    "tone": "friendly",
    "depth": "intermediate"
  },
  "defaults": {
    "git": { "auto_push": "ask", "auto_commit": true },
    "cross_model": {
      "provider": "codex",
      "codex_model": "LATEST",
      "gemini_model": "LATEST",
      "timeout_seconds": 3600
    },
    "timeouts": { "claude_agent": 1200, "cross_model": 3600, "writer": 600 },
    "consultant": { "style": "default", "custom_style": null },
    "notifications": { "telegram": { "enabled": false } }
  }
}
```

Write `.bmb/config.json` (if project or both):
```bash
mkdir -p .bmb/handoffs/.compressed .bmb/councils .bmb/sessions .bmb/worktrees
```
```json
{
  "version": 2,
  "git": { "auto_push": "ask", "auto_commit": true },
  "cross_model": { "provider": "codex", "codex_model": "LATEST", "gemini_model": "LATEST", "timeout_seconds": 3600 },
  "timeouts": { "claude_agent": 1200, "cross_model": 3600, "writer": 600 },
  "consultant": { "style": "default", "custom_style": null },
  "notifications": { "telegram": { "enabled": false } }
}
```

**Config priority**: Local `.bmb/config.json` > Global `~/.claude/bmb-profile.json` > Hardcoded defaults

### Step 4: Gitignore Protection
**Auto-add sensitive patterns to project `.gitignore`.** This is NON-OPTIONAL — always runs.

Check if `.gitignore` exists. If not, create it. Then ensure ALL of these patterns are present (append only missing ones):

```gitignore
# BMB runtime data (secrets, logs, sessions)
.bmb/

# Environment and secrets
.env
.env.*
!.env.example

# Credentials and tokens
*.pem
*.key
*.p12
*.pfx
*.jks
credentials.json
token.json
service-account*.json
*-credentials.json

# OS artifacts
.DS_Store
Thumbs.db
```

Implementation:
```bash
# For each pattern, check if already in .gitignore before appending
grep -qxF '.bmb/' .gitignore 2>/dev/null || echo '.bmb/' >> .gitignore
# ... repeat for each pattern
```

Do NOT duplicate existing entries. Only append missing ones.

### Step 5: Confirm
Show saved config summary + gitignore changes. Tell user:
- Re-run `/BMB-setup` anytime to change settings
- Telegram tokens go in `~/.zshenv`, NEVER in config files
- `.bmb/` is gitignored — safe for session logs and handoffs

## Security Notes
- **Secrets belong in `~/.zshenv` only**: `BMB_TG_TOKEN`, `BMB_TG_CHAT`, API keys
- **config.json stores flags, never values**: `telegram.enabled: true/false`, never the actual token
- **`.bmb/` is always gitignored**: contains session logs, handoffs, conversation history
- If user has existing `.env` with relevant vars, suggest migrating to `~/.zshenv` for cross-project consistency
