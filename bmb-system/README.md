# BMB (Be-my-butler) System — v0.3

Multi-agent orchestration pipeline with cross-model verification, idea lifecycle management, and human-centered brainstorming.

## v0.3 — Human-Centered Brainstorming Redesign

### 8 Axes
1. **Vertical pane split** — Consultant on the right (35% width) instead of bottom
2. **Real-time sync** — Hybrid feed+log sync protocol with clear channel hierarchy
3. **Idea lifecycle** — Persistent idea storage: spark → validate → elaborate → project | archive
4. **Beginner UX** — First-time gate, frictionless project creation from brainstorm
5. **Enhanced setup/onboarding** — 30-question user profiling, consultant persona selection
6. **Session continuity** — Carry-forward with atomic writes, pre-symlink reads
7. **Nudge system** — On-demand dashboard with stale idea reminders
8. **Cross-model plan review** — Codex reviews brainstorm plans before project creation

## Skills
| Skill | Description |
|-------|-------------|
| `/BMB` | Full A-to-Z pipeline (11.5 steps) |
| `/BMB-brainstorm` | Lead + Consultant brainstorming with idea lifecycle + Codex plan review |
| `/BMB-refactoring` | Parallel analysis + cross-model execution + review |
| `/BMB-setup` | First-time onboarding + project configuration |
| `/BMB-status` | Project/idea dashboard + nudge system |

## Agents (9)
| Agent | Model | Role |
|-------|-------|------|
| bmb-consultant | sonnet | Persistent advisor (Korean) — hybrid sync, profile-based persona, mid-session idea capture |
| bmb-architect | opus | Council debate + design. Queries Context7 for live docs. |
| bmb-executor | opus | Backend implementation. Queries Context7 before writing. |
| bmb-frontend | opus | Frontend implementation. Queries Context7 before writing. |
| bmb-tester | opus | Tests + coverage gate |
| bmb-verifier | opus | Verification + code review |
| bmb-simplifier | opus | Code cleanup |
| bmb-writer | sonnet | Documentation |
| bmb-analyst | sonnet | Retrospective analytics: Bird's Law severity, pattern_counts (bypassPermissions, read-only) |

## Scripts
| Script | Purpose |
|--------|---------|
| `scripts/bmb-config.sh` | Global/local config merge + first-time gate |
| `scripts/bmb-ideas.sh` | Idea lifecycle CRUD (spark → project → archive) |
| `scripts/bmb-learn.sh` | Auto-learning from corrections/decisions |
| `scripts/bmb-analytics.sh` | Session analytics telemetry |
| `scripts/cross-model-run.sh` | Cross-model wrapper (codex/gemini) with profiles: council, verify, review, test, exec-assist |
| `scripts/conversation-logger.py` | FIFO-based conversation logging |

## Config Architecture
```
~/.claude/bmb-profile.json    # Global user profile (30Q answers + persona + defaults)
{project}/.bmb/config.json    # Project-local overrides
~/.claude/bmb-system/config/defaults.json  # Hardcoded defaults (v2)
```
**Priority**: Local > Global profile defaults > Hardcoded defaults

## Project Runtime Structure
```
{project}/.bmb/
├── config.json          # /BMB-setup (v2)
├── session-log.md
├── consultant-feed.md   # Hybrid sync channel
├── knowledge.db         # FTS5
├── analytics/
│   └── analytics.db     # SQLite: sessions, events, pattern_counts
├── handoffs/
│   ├── .compressed/
│   ├── briefing.md
│   ├── plan-to-exec.md
│   ├── analyst-report.md
│   └── ...
├── councils/
│   └── LEGEND.md
├── sessions/{id}/
│   ├── conversation-log.md
│   ├── session-prep.md
│   ├── carry-forward.md
│   ├── brainstorm-record.md
│   ├── plan-draft.md
│   ├── plan-review.md
│   └── plan-final.md
└── worktrees/
```

## Global Idea Storage
```
~/.claude/bmb-ideas/
├── index.json           # Idea index (all ideas across projects)
└── {timestamp}-{slug}/
    ├── idea.md           # Title + summary + origin
    ├── status.json       # Current state + history
    ├── brainstorm-log.md # Full brainstorm conversation
    └── plan.md           # Implementation plan (if generated)
```

## Key Improvements over v0.2
- Idea lifecycle management (persistent across projects)
- 30-question user profiling for personalized experience
- Consultant persona customization (name, tone, depth)
- Cross-model plan review via Codex before project creation
- Carry-forward with atomic writes (temp+mv)
- Pre-symlink carry-forward reads (Finding 2 fix)
- Hybrid feed+log sync protocol (Finding 3 fix)
- First-time gate preventing setup-less runs
- /BMB-status dashboard with nudge system
- Vertical pane split for better screen real estate
- Context overflow protocol for long brainstorming sessions
- Mid-session side-idea capture via Consultant
