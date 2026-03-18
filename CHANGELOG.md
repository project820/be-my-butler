# Changelog

All notable changes to BMB will be documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioned per [Semantic Versioning](https://semver.org/).

## [0.3.5] - 2026-03-13

### Added
- **Lead Retrospective (Step 11)** — dedicated retrospective step before Cleanup. Forces `bmb_learn` call (minimum 1 per session), Analyst report relay to user, promotion check, and auto-memory save. Pipeline is now 12 steps.
- **Portable `timeout` fallback** — `cross-model-run.sh` now defines a `perl`-based `timeout()` function when GNU coreutils `timeout` is absent (macOS default). Eliminates the primary cause of cross-model pane silent exit (exit 127 under `set -euo pipefail`).
- **Codex pre-flight check** — `_codex_preflight()` runs a 10-second smoke test before each cross-model call; failure records an incident and exits with code 5 instead of hanging.
- **stderr separation** — `codex exec` stdout and stderr are captured to separate files; stderr is scanned for auth/error patterns and recorded to the incident spool.
- **Exit code taxonomy** (cross-model-run.sh): 0=success, 1=missing/general, 2=timeout, 3=killed, 4=auth failure, 5=preflight failure, 6=stall detected.
- **Haiku Monitor agent** (`agents/bmb-monitor.md`) — Lead-owned lightweight observer using Claude Haiku. Metadata-only stall detection (file mtime/size via `stat`/`wc -c`), process liveness checks, timeout warnings at 90%/100%. Blind phase filtering prevents test verdicts and coverage data from reaching Consultant during Steps 6–7. Optional dependency: Monitor failure never blocks the pipeline.

### Changed
- **12-step pipeline** — Step 11 (Cleanup) split into Step 11 (Lead Retrospective) + Step 12 (Cleanup). All recipe step tables updated.
- **`skills/bmb/bmb.md`** — Step 11 rewritten as Lead Retrospective with 5 substeps (11.1 bmb_learn, 11.2 analyst relay, 11.3 promotion check, 11.4 auto-memory, 11.5 context check); original cleanup items moved to Step 12.
- **`scripts/cross-model-run.sh`** — preflight guard added; timeout fallback placed at top of file before any invocation; exit codes refined for all failure paths.
- **`config/defaults.json`** — added `retrospective.min_learnings_per_session: 1`, `cross_model.preflight_timeout: 10`.

### Fixed
- `timeout` command missing on macOS causing cross-model panes to die silently (exit 127 from `set -euo pipefail`)
- Retrospective steps skipped by Lead when commit/push felt like pipeline completion
- `bmb_learn` never called in production sessions — learnings.md remained empty across pipeline runs

## [0.3.4] - 2026-03-13

### Added
- **External dependency incident capture** — `bin/codex` Python shim transparently wraps the real codex binary; records auth failures, stalls, timeouts, rate limits, and crashes to NDJSON spool (never SQLite directly)
- **`bmb-external-incidents.sh`** — NDJSON spool management: record, import, rotate, list, sanitize, classify
- **Recovery-first bounded restart** — on cross-model timeout, `cross-model-run.sh` attempts one restart (300s) before graceful degradation to Claude-only mode
- **Profile-based timeouts** — each cross-model profile (`council`, `verify`, `review`, `test`, `exec-assist`) gets its own default timeout; no more shared 3600s for all profiles
- **External incident analytics** — `bmb_analytics_import_incidents()` bridges NDJSON spool → `external_incidents` table + `events` + `pattern_counts` at pipeline init
- **Analyst dependency reports** — Step 10.5 now queries `external_incidents` and recovery patterns for richer retrospectives (`bmb-analyst.md` Step 3.5)
- **Monitor subagent config** — `defaults.json` keys for Lead-owned metadata-only monitor (Haiku-class, no pane, no daemon)

### Changed
- **`cross-model-run.sh`** — incident recording on all failure types (cli_missing, timeout, nonzero, auth); differentiated exit codes (0=success, 1=missing/general, 2=timeout, 3=killed)
- **`defaults.json`** — added `timeouts.*`, `recovery.*`, `monitor.*`, and `incidents.*` config keys
- **`skills/bmb/bmb.md`** — Step 1 now sources `bmb-external-incidents.sh` and imports incidents at init; graceful degradation rewritten to recovery-first policy with exit-code classification
- **`skills/bmb-brainstorm/SKILL.md`** — Phase 4.5 updated with profile-based timeout notes and exit-code-based degradation branches
- **`agents/bmb-consultant.md`** — added Monitor Lifecycle Updates section (v0.3.4) with blind-phase isolation rules for monitor events
- **`agents/bmb-analyst.md`** — added Step 3.5: External Dependency Failures & Recovery

### Fixed
- Codex hangs during re-test/re-verify loops now detected via output-gap stall heuristic (primary) + CPU auxiliary signal
- Flat 3600s cross-model timeout replaced by per-profile defaults (targeted in v0.3.0 Known Issues)
- Single-writer SQLite rule preserved: shim writes NDJSON only; Lead is the sole SQLite writer
- **SQL injection in `bmb-external-incidents.sh`** — `$ts`, `$ts_ep`, `$ec` now escaped via `sed "s/'/''/g"` before INSERT (matched existing pattern for `$det`/`$src`/`$ek`)
- **Blocking read in `bin/codex`** — replaced `proc.stdout.read(4096)` with `select.select()` loop; stall detection now executes correctly in non-TTY mode
- **Missing `cross_model_verify` timeout** — added `timeouts.cross_model_verify: 900` to `defaults.json`; verify steps no longer fall back to unspecified default

### Constraints
- No daemon, no always-on watcher
- CPU used as auxiliary stall signal only (not sole indicator)
- Large output streamed to temp file (no RAM buffering)
- Consultant blind-phase isolation preserved

## [0.3.0] - 2026-03-13

### Added
- **Human-centered brainstorming redesign** — 8-axis upgrade to the brainstorming pipeline
  - Vertical pane split (Consultant at 35% right pane instead of bottom)
  - Real-time hybrid sync protocol (feed + log) with clear channel hierarchy
  - Idea lifecycle management: spark → validate → elaborate → project | archive
  - First-time gate with frictionless project creation from brainstorm
  - 30-question user profiling with consultant persona selection
  - Session continuity: carry-forward with atomic writes (temp+mv)
  - On-demand nudge system: `/BMB-status` dashboard with stale idea reminders
  - Cross-model plan review: Codex reviews brainstorm plans before project creation
- **Config infrastructure** (`bmb-config.sh`) — 3-layer merge: `defaults.json` → global profile → local config
- **Idea lifecycle CRUD** (`bmb-ideas.sh`) — persistent idea storage across projects with status transitions
- **`/BMB-status` skill** — project/idea dashboard with nudge system
- **`/BMB-setup` first-time onboarding** — 30Q profiling, persona selection, settings scope
- **Cross-model review profile** — `--profile review` with `-o OUTPUT_FILE` and `-` stdin flags

### Changed
- **Consultant agent** — added unified sync protocol, profile-based personalization, mid-session idea capture
- **Brainstorm skill** — complete rewrite with phases: Setup, Spawn Consultant, Brainstorming (NEW_IDEA handler, context overflow), Idea Lifecycle Gateway, Cross-Model Plan Review, Project Creation, Cleanup
- **Pipeline skill** (`bmb.md`) — vertical split layout, hybrid feed init, config loading, NEW_IDEA handler, enhanced carry-forward generation
- **`defaults.json`** — version 2 with profile template, review model config (`gpt-5.4`, `xhigh` effort)
- **`cross-model-run.sh`** — refactored all Python blocks to env var + heredoc pattern, consolidated config reads

### Fixed
- Path traversal vulnerability in idea lifecycle (`../../escape` blocked by `bmb_idea_validate_id()`)
- Unquoted heredocs allowing shell injection → changed to `<< 'HEREDOC_EOF'`
- Python shell interpolation in cross-model-run.sh → refactored to env var + heredoc
- ShellCheck SC2155 in bmb-ideas.sh (declare and assign separately)
- Markdown lint false positives from heredoc in code fences (MD012/MD025/MD046 disabled)
- Unrelated files (gws-*, ui-ux-pro-max) removed from git tracking

### Known Issues
- Codex can hang during re-test/re-verify loops (54+ min observed) — no automatic detection yet (targeted for v0.3.4)
- Cross-model timeout is flat 3600s for all profiles — per-profile timeouts planned for v0.3.4

## [0.2.0] - 2026-03-12

### Added
- **Analytics subsystem** — file-backed SQLite telemetry (`bmb-analytics.sh`)
  - 8 helper functions: init, use_state, set_recipe, step_start, step_end, event, count_pattern, end_session
  - 3 tables: sessions, events, pattern_counts
  - Cross-shell state recovery via `.bmb/analytics/state.env`
  - Bird's Law severity model (1:10:30:600) for event classification
- **Analyst agent** (`bmb-analyst.md`) — retrospective analysis after each pipeline run
  - Queries analytics DB for session metrics, recurring patterns, agent reliability
  - Bird's Law severity classification in reports
  - Cross-session pattern detection (3+ sessions)
  - New pipeline Step 10.5 between Writer and Cleanup
- **Consultant Coordinator model** — industrial-grade situational awareness
  - Dual-channel communication: SendMessage (authoritative realtime) + feed (durable narrative)
  - Post-briefing protocol: blind phase results delivered after completion, not during
  - Overtime nudging: timeout-based user reassurance and warning
  - 12 fixed JSON event templates for structured lifecycle tracking
- **3-tier reporting hierarchy** — clear contract between Lead and user
  - Tier 1 (Immediate): rollback, system failure, design change
  - Tier 2 (Post-hoc): library change, agent respawn, minor adjustment
  - Tier 3 (No report): routine file ops, test execution, normal lifecycle
- **Context7 integration** for all implementation agents (Executor, Frontend, Architect)
  - On-demand library documentation lookup via MCP
  - When-to-use / when-not-to-use guidelines
- **Pattern frequency tracking** (`pattern_counts` table) — count-based aggregation for high-frequency identical events, replacing unbounded row insertion
- **Structured learning mirror** (Tier 3) — `bmb-learn.sh` mirrors human-readable learnings into analytics DB with stable grouping key via `cksum`
- **Full agent lifecycle telemetry** in Steps 5, 6, 7 — spawn/complete/timeout events for all agents

### Changed
- **All agents unified on `bypassPermissions`** — eliminates `dontAsk` fallback complexity; user is not prompted for every permission decision
- **Analyst timeout**: 180s default, 300s configurable max (via `.bmb/config.json`)
- Agent count: 8 → 9 (added Analyst)
- Pipeline step count: 11 → 11.5 (added Step 10.5)
- Recipe reference updated: feature/bugfix/refactor/infra pipelines now include `→ analyst`

### Fixed
- SQL single-quote escaping: replaced broken `${var//\'/\'\'}` with `sed`-based `_bmb_sql_escape` helper
- zsh compatibility: renamed `local status=` to `local end_status=` (avoids zsh read-only variable collision)
- `.current.env` values now double-quoted (spaces in step labels no longer break sourcing)
- `BMB_ANALYTICS_ACTIVE` now exported in current shell after `bmb_analytics_init` (Tier 3 mirror activates correctly)
- Consultant briefing path corrected to `.bmb/handoffs/briefing.md`

### Known Issues
- Context7 live validation pending (connected but not yet tested in a full pipeline run)
- Analyst cross-session queries require 3+ sessions of data accumulation
- Public repo CI may need ShellCheck update for new `bmb-analytics.sh`

## [0.1.0] - 2026-03-10

### Added
- 11-step multi-agent orchestration pipeline (`/BMB` skill)
- 8 specialized agents: Consultant, Architect, Executor, Frontend, Tester, Verifier, Simplifier, Writer
- Cross-model blind verification (Codex, Gemini support)
- Council debate with blind divergent framing
- Worktree isolation for safe parallel execution
- 6 recipe types: feature, bugfix, refactor, research, review, infra
- FTS5 knowledge base with `knowledge-index.sh` and `knowledge-search.sh`
- 3-tier auto-learning system (project → global → CLAUDE.md promotion)
- Conversation logger (Python FIFO-based async logging)
- Cross-model runner with `--profile` permission control
- `/BMB-brainstorm`, `/BMB-refactoring`, `/BMB-setup` skills
- Install / Doctor / Uninstall lifecycle scripts
- Interactive architecture docs page (GitHub Pages)
- i18n: English, Korean, Japanese, Traditional Chinese
- CI workflows: ShellCheck, markdownlint, install smoke test
- Demo todo-app example project

### Fixed
- CI workflow failures (ShellCheck, markdownlint, install test)
- Repository URL references updated to `project820/be-my-butler`
- GitHub metadata: topics, homepage URL, Discussions enabled

### Known Issues
- `bmb-learn.sh`: missing `mkdir -p` for global learnings directory
- Worktree cleanup does not delete branches after `git worktree remove`

[0.3.5]: https://github.com/project820/be-my-butler/releases/tag/v0.3.5
[0.3.4]: https://github.com/project820/be-my-butler/releases/tag/v0.3.4
[0.3.0]: https://github.com/project820/be-my-butler/releases/tag/v0.3.0
[0.2.0]: https://github.com/project820/be-my-butler/releases/tag/v0.2.0
[0.1.0]: https://github.com/project820/be-my-butler/releases/tag/v0.1.0
