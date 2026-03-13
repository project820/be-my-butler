# BMB v0.3.4 — External Dependency Incidents + Monitor Recovery

**Date:** 2026-03-13  
**Status:** READY  
**References:** `plans/bmb-v0.3.4-codex-timeout.md`, `plans/bmb-monitor-draft.md`

## Why This Exists

v0.3.4 is driven by real incidents observed during pipeline execution on 2026-03-13:

- Codex auth 401 required manual logout/login recovery before work could continue
- a cross-model re-tester hung for 54+ minutes without producing a result file
- the stall was escalated manually instead of being detected automatically
- degradation to Claude-only was necessary, but only after the team realized the run was effectively dead

The current system records pipeline-internal events reasonably well, but it does **not** reliably capture:

- off-session dependency failures
- failures from another terminal
- silent Codex stalls
- recovery attempts before fallback

This causes retrospectives to underreport operational friction and makes recurring Codex instability hard to learn from.

## Goals

v0.3.4 succeeds only if all of the following are true:

- dependency incidents can be captured automatically without user logging
- off-session incidents can be imported into session analytics safely
- a lightweight monitor reduces Lead context waste from repetitive polling
- targeted re-test / re-verify loops use shorter timeout profiles than the main pipeline
- recovery is attempted first, and graceful degradation happens only after bounded recovery fails
- analyst reports can mention both failures and recoveries

## Non-Goals

- no daemon
- no machine-global watcher process
- no direct multi-process writes into `.bmb/analytics/analytics.db`
- no full-output buffering in RAM for large Codex runs
- no broad repo-reading monitor

## Invariants

1. **Lead remains the only SQLite writer**
2. **No user-facing manual logging flow**
3. **Monitor is metadata-only by default**
4. **Recovery-first, fallback-last**
5. **Blind-phase isolation must remain intact**

## Core Design

### 1. Global External Incident Spool

Create a global NDJSON spool:

```text
~/.claude/bmb-system/runtime/external-incidents.ndjson
```

Purpose:

- durable record for off-session failures
- later imported by Lead into session analytics
- keeps single-writer invariant intact

### 2. Python-Backed Codex Shim

Create:

```text
~/.claude/bmb-system/bin/codex
```

Requirements:

- transparent wrapper around the real `codex`
- preserve TTY for interactive commands
- stream/file-back large output, do not buffer full transcripts in RAM
- classify auth failure, missing CLI, nonzero exit, timeout, stall signals
- record recovery on successful login / successful follow-up execution

### 3. Lightweight Monitor Subagent

Reference draft:

```text
plans/bmb-monitor-draft.md
```

Requirements:

- Lead-owned
- Haiku-class
- no pane
- metadata-only
- reports state changes, not periodic prose
- can notify Consultant with filtered lifecycle-safe updates only

Monitor observes:

- result-file existence
- file size / modification time
- PID liveness
- timeout progress
- event-stream growth
- optional low CPU as supporting evidence only

### 4. Recovery-First, Fallback-Last

Graceful degradation is important, but it must not be the first reaction.

Required policy:

1. Detect likely issue
   - no result file
   - no event growth
   - no `mtime` change for idle window
   - process still alive but effectively idle
2. Classify
   - auth
   - missing CLI
   - timeout
   - likely stall/hang
3. Attempt bounded recovery
   - auth: recovery flow
   - stall: one bounded restart attempt
   - targeted re-test / re-verify: shorter timeout profile
4. Escalate
   - if recovery fails or stall repeats, record it
   - only then degrade to Claude-only / single-provider mode

### 5. Targeted Timeout Profiles

Do not reuse the main 3600s cross-model timeout for focused retry loops.

Recommended defaults:

```json
{
  "timeouts": {
    "cross_model": 3600,
    "cross_model_retest": 600,
    "cross_model_reverify": 600
  },
  "recovery": {
    "cross_model_restart_attempts": 1
  },
  "monitor": {
    "enabled": true,
    "poll_sec": 30,
    "idle_stall_sec": 180,
    "consultant_reporting": "filtered"
  },
  "analytics": {
    "external_incident_lookback_sec": 86400,
    "external_incident_retention_days": 30
  }
}
```

## Event Keys

Start with:

- `codex_auth_401`
- `codex_cli_missing`
- `codex_exec_nonzero`
- `codex_exec_stalled`
- `codex_review_timeout`
- `codex_review_empty_output`
- `codex_retest_timeout`
- `codex_recovery_restart_attempted`
- `codex_recovery_restart_failed`
- `supermemory_mcp_handshake_failed`
- `dependency_login_recovered`

## Files to Modify

| File | Change |
|------|--------|
| `scripts/bmb-external-incidents.sh` | New helper for spool, import, sanitize, rotate, classify |
| `scripts/bmb-analytics.sh` | Import bridge + pattern counting + recovery markers |
| `scripts/cross-model-run.sh` | Incident capture, stall handling, recovery-first logic, targeted timeouts |
| `config/defaults.json` | New timeout/recovery/monitor defaults |
| `README.md` | Document v0.3.4 behavior |
| `~/.claude/skills/bmb/bmb.md` | Import incidents at setup, spawn monitor, recovery-first logic |
| `~/.claude/skills/bmb-brainstorm/SKILL.md` | Make plan review path observable and incident-aware |
| `~/.claude/agents/bmb-consultant.md` | Accept filtered monitor lifecycle updates |
| `~/.claude/agents/bmb-analyst.md` | Report dependency failures, recoveries, and patterns |

## Monitor Reporting Rules

To Lead:

```text
[MONITOR] agent=tester step=6 state=stalled idle_sec=240 ts=14:22
[MONITOR] agent=tester step=6 state=cpu_idle_no_output idle_sec=240 cpu_pct=0.1 ts=14:22
[MONITOR] agent=codex-review step=2C state=timeout_imminent elapsed=540 timeout=600 ts=14:11
```

To Consultant:

- lifecycle-safe only
- no verdict payloads during blind phases
- if unsure, report only to Lead

## Verification Checklist

1. `bash -n scripts/bmb-external-incidents.sh`
2. `bash -n scripts/bmb-analytics.sh`
3. `bash -n scripts/cross-model-run.sh`
4. Trigger a fake off-session incident → confirm append to spool
5. Start `/BMB` → confirm import into analytics as dependency failure
6. Confirm dedupe on restart
7. Confirm recovery is recorded distinctly
8. Simulate targeted re-test hang → confirm 600s profile, not 3600s
9. Confirm exactly one bounded restart attempt before degradation
10. Confirm monitor stays metadata-only and does not read large handoff bodies by default
11. Confirm Consultant receives filtered lifecycle updates only
12. Confirm no secrets are written to spool or SQLite

## Recommendation

Implement v0.3.4 as an operational reliability layer on top of v0.3.2, not as a separate feature. The value is not cosmetic telemetry; it is faster detection, bounded recovery, cleaner fallback decisions, and better retrospectives.
