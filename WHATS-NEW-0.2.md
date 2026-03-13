# What's New in BMB v0.2.0

**Release date**: 2026-03-12

BMB v0.2 is a major operational upgrade that brings industrial-grade observability, self-improvement, and real-time awareness to the multi-agent pipeline. Inspired by Frank Bird's safety ratio (1:10:30:600), this release treats every small repeated mistake as a precursor to major failure — and gives BMB the tools to detect and report those patterns.

---

## Highlights

### Analytics Subsystem (Bird's Law)

BMB now records structured telemetry for every pipeline run.

```
.bmb/analytics/
  analytics.db     ← SQLite with sessions, events, pattern_counts
  state.env        ← cross-shell state recovery
  steps/           ← per-step timing files
```

Every agent spawn, timeout, merge conflict, and loop-back is logged with 5W1H metadata (who, what, when, where, why, how). High-frequency identical patterns use count-based aggregation instead of unbounded row insertion.

**Bird's Law severity model**:

| Severity | Industrial | BMB Equivalent |
|----------|-----------|----------------|
| 600 (near-miss) | 아차사고 | Routine events (file ops) |
| 30 (property damage) | 물적 피해 | Loop-back, timeout |
| 10 (minor injury) | 경상 | Agent crash, merge conflict |
| 1 (major/fatal) | 중상/사망 | System failure, rollback |

### Analyst Agent (Step 10.5)

A new retrospective analyst runs after the Writer and before Cleanup. It queries the analytics DB to produce:

- Current session metrics and incident log
- Recurring pattern analysis (from `pattern_counts`)
- Agent reliability statistics
- Learning promotion candidates
- Timeout adequacy assessment

The Analyst never auto-edits your `CLAUDE.md` — recommendations only. Cross-session trends activate after 3+ sessions.

### Consultant as Coordinator

The Consultant's role is now modeled after a heavy industry Coordinator:

- **Full situational awareness** — knows everything happening in the pipeline
- **Zero command authority** — observes and reports, never directs
- **Dual-channel communication**:
  - `SendMessage` = authoritative real-time lifecycle events (JSON one-liners)
  - `consultant-feed.md` = durable narrative for bootstrap/recovery
- **Post-briefing** — receives blind phase results only after verification completes (unbiased analysis)
- **Overtime nudging** — reassures users at 100% timeout, warns beyond

### 3-Tier Reporting Hierarchy

Clear contract between Lead and user:

| Tier | When | Examples |
|------|------|----------|
| Immediate | System-critical | Rollback, design change, major failure |
| Post-hoc | Notable but non-blocking | Library change, agent respawn |
| No report | Routine | File ops, test execution, normal lifecycle |

### Context7 for All Implementation Agents

Executor, Frontend, and Architect can now query up-to-date library documentation on demand via Context7 MCP. No more guessing API signatures — agents check current docs when the codebase doesn't show a clear pattern.

### `bypassPermissions` Unification

All BMB agents now run with `bypassPermissions`. The user steers strategy, the Lead handles execution autonomously with mandatory reporting for critical events. No more `dontAsk` fallback paths.

---

## Breaking Changes

- **Permission mode**: All agents now use `bypassPermissions` instead of mixed `dontAsk`/`bypassPermissions`. If you previously relied on permission prompts during agent execution, those prompts are gone.
- **Pipeline step count**: 11 → 11.5 (Step 10.5 added). Recipe references updated accordingly.
- **Agent count**: 8 → 9 (Analyst added).

## Migration from v0.1

1. Run `install.sh` to get the new files
2. No config changes required — analytics activates automatically
3. `.bmb/config.json` gains optional `timeouts.analyst` field (default: 180s)
4. Existing sessions and learnings are fully preserved

## Bug Fixes

- SQL injection protection now works correctly (sed-based escaping)
- zsh compatibility restored (no more `read-only variable: status`)
- Step labels with spaces no longer break state file sourcing
- Analytics mirror (Tier 3 learning) now activates reliably after init

---

## Stats

- **New files**: 2 (`bmb-analytics.sh`, `bmb-analyst.md`)
- **Modified files**: 6 (pipeline, consultant, executor, frontend, architect, learn)
- **Docs updated**: 3 (README, architecture, interactive docs)
- **Tests**: 121+ across 2 cross-model rounds
- **Verification rounds**: 4 (2 cross-model + 2 targeted)

## Full Changelog

See [CHANGELOG.md](./CHANGELOG.md) for the complete list of changes.
