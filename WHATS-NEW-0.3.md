# What's New in BMB v0.3

## v0.3.4 — External Dependency Incidents + Monitor Recovery

**Release date**: 2026-03-13

BMB v0.3.4 adds operational reliability for cross-model pipelines. Codex failures are now captured automatically, the pipeline recovers before giving up, and each cross-model profile gets its own timeout budget.

### Highlights

#### Automatic Incident Capture

A transparent Python shim (`bmb-system/bin/codex`) wraps the real Codex binary. All failures — auth errors, stalls, timeouts, rate limits, crashes — are recorded to an NDJSON spool without any manual logging. The spool is imported into `analytics.db` at pipeline start so the Analyst (Step 10.5) sees the full dependency health picture.

#### Recovery-First Bounded Restart

When a cross-model agent times out, the pipeline no longer immediately falls back to Claude-only mode. It attempts **one bounded restart** (300s) first. If the restart also fails, it degrades gracefully. This single recovery attempt catches transient failures without introducing indefinite waits.

#### Profile-Based Timeouts

All cross-model profiles share a flat 3600s timeout was a known issue in v0.3.0. v0.3.4 fixes this:

| Profile | Default |
|---------|---------|
| `council` | 600s |
| `verify` | 600s |
| `review` | 600s |
| `test` | 1200s |
| `exec-assist` | 3600s |
| `recovery_restart` | 300s |

#### Codex Shim Design

- TTY passthrough — interactive Codex sessions work unchanged
- Non-TTY: large output streamed to temp file, not RAM buffer
- Stall detection: output gap > 180s (primary) + CPU < 5% (auxiliary only)
- Single-writer SQLite rule preserved: shim writes NDJSON only; Lead imports

### New Files

| File | Purpose |
|------|---------|
| `bmb-system/bin/codex` | Transparent Python shim for Codex incident capture |
| `bmb-system/scripts/bmb-external-incidents.sh` | NDJSON spool: record, import, rotate, sanitize, classify |

### Modified Files

| File | Change |
|------|--------|
| `bmb-system/scripts/bmb-analytics.sh` | +3 functions: `import_incidents`, `pattern_count`, `recovery_marker` |
| `bmb-system/scripts/cross-model-run.sh` | Profile timeouts, incident recording, recovery-first restart |
| `bmb-system/config/defaults.json` | `timeouts.*`, `recovery.*`, `monitor.*`, `incidents.*` keys |
| `skills/bmb/bmb.md` | Step 1 init sources incidents; recovery-first degradation policy |
| `skills/bmb-brainstorm/SKILL.md` | Phase 4.5: profile timeouts + exit-code degradation branches |
| `agents/bmb-consultant.md` | Monitor Lifecycle Updates section with blind-phase isolation |
| `agents/bmb-analyst.md` | Step 3.5: External Dependency Failures & Recovery queries |

### Key Constraints

- No daemon, no always-on watcher
- CPU as auxiliary stall signal only (not sole indicator)
- Large output streamed to disk (no RAM buffering)
- Consultant blind-phase isolation preserved

---

# What's New in BMB v0.3.0

**Release date**: 2026-03-13

BMB v0.3 is a human-centered redesign of the brainstorming pipeline. Eight axes of improvement make BMB more accessible to beginners, more persistent in tracking ideas, and more robust in cross-model interactions. The Consultant becomes a true real-time collaborator, ideas gain a durable lifecycle, and Codex reviews your plans before you commit to building them.

---

## Highlights

### Idea Lifecycle Management

Ideas are no longer ephemeral. Every spark captured during brainstorming is persisted and tracked through a clear lifecycle:

```
spark → validate → elaborate → project | archive
```

```
~/.claude/bmb-ideas/
├── index.json
└── 20260313T143000-auth-refactor/
    ├── idea.md
    ├── status.json
    ├── brainstorm-log.md
    └── plan.md
```

Use `/BMB-status` to see all ideas across projects, get nudged about stale ones, and promote validated ideas into projects.

### 30-Question User Profiling

First-time setup now walks you through 30 questions across 5 sections:

1. **Background** — role, expertise, coding experience
2. **Work style** — solo/team, explanation depth, jargon level
3. **Communication** — MBTI, decision style, stress communication
4. **Consultant persona** — name, tone, depth for your AI advisor
5. **Settings scope** — global vs project-local preferences

Your profile shapes how every agent communicates with you.

### Vertical Pane Split + Hybrid Sync

The Consultant now runs in a **35% right pane** instead of a cramped bottom split. Communication uses a hybrid sync protocol:

| Channel | Purpose | Priority |
|---------|---------|----------|
| `SendMessage` | Real-time authoritative events | Highest |
| `consultant-feed.md` | Durable narrative + bootstrap | Primary |
| `conversation-log.md` | Full session record | Supplementary |

### Cross-Model Plan Review

Before creating a project from a brainstorm, Codex reviews the implementation plan:

1. Draft plan generated during brainstorming
2. Plan sent to Codex via `cross-model-run.sh --profile review`
3. Codex provides findings-first critique
4. Lead incorporates feedback into the final plan
5. Only then does the plan become a project

### Config Infrastructure (3-Layer Merge)

```
defaults.json          ← hardcoded defaults (version 2)
  ↓ merge
bmb-profile.json       ← global user profile (30Q answers)
  ↓ merge
.bmb/config.json       ← project-local overrides
```

`bmb-config.sh` handles the merge with first-time gate detection. If no profile exists, `/BMB-setup` runs automatically.

### Session Continuity

- **Carry-forward** — atomic writes (temp+mv) prevent corruption
- **Pre-symlink reads** — carry-forward is read before session symlink updates
- **Context overflow** — long brainstorming sessions detect token pressure and offer to wrap up gracefully

---

## New Skill: `/BMB-status`

Dashboard for all ideas and projects:

- Lists ideas by lifecycle state
- Flags stale ideas (no activity for 7+ days)
- Shows project mapping (which ideas became projects)
- Works across all project directories

---

## Breaking Changes

- **Config format**: `defaults.json` is now version 2 with `_profile_template` section
- **Consultant protocol**: Dual-channel sync is now the default; old single-feed mode is no longer supported
- **First-time gate**: Running `/BMB` or `/BMB-brainstorm` without a profile triggers `/BMB-setup` automatically

## Migration from v0.2

1. Run `install.sh` to get the new files
2. Your first `/BMB` or `/BMB-brainstorm` run will trigger the 30Q profiling setup
3. Existing `.bmb/config.json` files are preserved and merged with the new defaults
4. Existing analytics data (`analytics.db`) is fully compatible

## Security Fixes

- Path traversal in idea IDs now blocked by `bmb_idea_validate_id()`
- Heredoc injection prevented by quoting all user-derived heredocs (`<< 'EOF'`)
- Python shell interpolation eliminated from `cross-model-run.sh`

---

## Stats

- **New files**: 4 (`bmb-config.sh`, `bmb-ideas.sh`, `bmb-status/SKILL.md`, `cross-model-run.sh --profile review`)
- **Modified files**: 7 (brainstorm SKILL.md, bmb.md, consultant, setup, defaults.json, README, SKILL.md router)
- **Security fixes**: 3 (path traversal, heredoc injection, Python interpolation)
- **Verification rounds**: 4 (2 cross-model + 2 Claude-only after Codex degradation)
- **Lines of code**: ~2,100 added across skills, agents, and scripts

## Full Changelog

See [CHANGELOG.md](./CHANGELOG.md) for the complete list of changes.
