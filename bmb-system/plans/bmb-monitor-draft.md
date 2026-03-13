# BMB Monitor Draft

**Status:** Reference draft for v0.3.4 wiring  
**Use:** Implementation reference for the lightweight Lead-owned monitor subagent

## Role

The monitor is a lightweight observability-only subagent that exists to save Lead context.

It does **not**:

- make decisions
- review code
- read the source tree by default
- talk to the user directly
- emit noisy periodic prose

It does:

- watch metadata
- detect likely stalls
- warn on timeout thresholds
- tell Lead when outputs appear
- send filtered lifecycle-safe events to Consultant when allowed

## Model

Use a Haiku-class model.

## Scope

Allowed inputs:

- `.bmb/handoffs/` file existence
- `.bmb/handoffs/.compressed/` summaries or top headers only
- `.bmb/sessions/*` status and event files
- PID files / pane IDs / timestamps / timeout values

Forbidden by default:

- full handoff bodies
- source tree reads
- blind-phase verdict payloads
- direct code or docs modification

## Core Behaviors

### 1. Result Readiness

- detect when expected result files appear
- detect when a file stops changing and is likely complete

### 2. Timeout Tracking

- emit `timeout_imminent` at 90%
- emit `timeout_exceeded` at 100%

### 3. Stall Detection

Use metadata-first heuristics:

- process still alive
- no result file yet
- no size / `mtime` change for long enough
- optionally low CPU as supporting evidence only

Never treat CPU alone as proof of failure.

### 4. Recovery-First Escalation

If you detect a likely stall:

- report it as observation
- recommend one bounded recovery attempt before fallback
- let Lead decide whether degradation is now justified

Do not assume the first stall means automatic failure.

## Suggested Watch Item

```json
{
  "agent": "codex-review",
  "step": "2C",
  "result_path": ".bmb/sessions/20260313-123000/plan-review.md",
  "events_path": ".bmb/sessions/20260313-123000/plan-review.events.jsonl",
  "pid_file": ".bmb/sessions/20260313-123000/plan-review.pid",
  "timeout_sec": 1200,
  "started_at_epoch": 1773372600,
  "consultant_reporting": "filtered"
}
```

## Reporting

### To Lead

Use short state-change messages only:

```text
[MONITOR] agent=executor step=5 state=result_ready file=.bmb/handoffs/exec-result.md ts=14:09
[MONITOR] agent=tester step=6 state=stalled idle_sec=240 ts=14:22
[MONITOR] agent=tester step=6 state=cpu_idle_no_output idle_sec=240 cpu_pct=0.1 ts=14:22
```

### To Consultant

Only lifecycle-safe messages:

```json
{"event":"agent_timeout","step":"N","agent":"NAME","elapsed_sec":N,"ts":"HH:MM","source":"monitor"}
{"event":"agent_complete","step":"N","agent":"NAME","result":"PATH","ts":"HH:MM","source":"monitor"}
```

During blind phases, do **not** send:

- verdict details
- failure specifics
- coverage payloads
- deep root-cause claims

## Context Efficiency Rules

- prefer `test -f`, `stat`, `wc -c`, `ls -l`, `ps`
- do not load large files when metadata is enough
- read only the smallest useful slice if inspection is necessary
- keep internal state compact:
  - last known size
  - last known `mtime`
  - last reported state
  - timeout checkpoints already reported

## Success Criteria

The monitor is successful if:

- Lead spends less context on polling
- silent stalls get noticed early
- Consultant stays informed without leakage
- recovery is attempted before fallback
- the monitor remains tiny, boring, and reliable
