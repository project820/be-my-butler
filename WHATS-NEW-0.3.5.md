# What's New in BMB v0.3.5

**Lead Retrospective Enforcement + Cross-Model Reliability**

---

## The Problem This Solves

Two systemic failures were identified across pipeline sessions:

1. **Broken learning loop** — Lead skipped the retrospective and called cleanup "done" after commit/push. `bmb_learn` was never called. `learnings.md` stayed empty. The promotion check never ran. BMB ran session after session making the same mistakes.

2. **Silent cross-model failures on macOS** — `timeout` command is not available on macOS by default. Under `set -euo pipefail`, a missing `timeout` causes the entire cross-model pane to exit silently with code 127. This was the primary cause of the 50%+ cross-model failure rate observed across recent sessions.

---

## What Changed

### Step 11: Lead Retrospective (NEW)

The pipeline is now **12 steps**. Step 11 is a dedicated retrospective that runs *before* Cleanup:

| Substep | Action | Mandatory? |
|---------|--------|------------|
| 11.1 | `bmb_learn` call (MISTAKE or PRAISE) | Always |
| 11.2 | Read `analyst-report.md`, relay key findings to user | If report exists |
| 11.3 | Scan `learnings.md` for recurrence ≥2 → propose CLAUDE.md promotion | If learnings exist |
| 11.4 | Save session insights to auto-memory | Optional |
| 11.5 | Context check — skip 11.2–11.4 if tight, never skip 11.1 | Always |

**Rule**: Even if context is critically low, `bmb_learn` (1 call, <100 tokens) is always executed.

### Step 12: Cleanup (renamed from Step 11)

All previous Step 11 content (Consultant exit, logger shutdown, git commit/push, session-prep generation, worktree cleanup, Telegram notification) moves to Step 12.

### Portable `timeout` Fallback

`cross-model-run.sh` now defines a `perl`-based `timeout()` shim at startup when GNU coreutils is absent:

```bash
if ! command -v timeout &>/dev/null; then
  timeout() {
    local duration="$1"; shift
    perl -e '
      $SIG{ALRM} = sub { kill 9, $pid; exit 124 };
      alarm(shift);
      $pid = fork // die;
      if ($pid == 0) { exec @ARGV; die "exec: $!" }
      waitpid($pid, 0);
      exit ($? >> 8);
    ' "$duration" "$@"
  }
fi
```

No external dependencies. Pure perl (macOS built-in).

### Pre-Flight Check

Before each cross-model call, `_codex_preflight()` runs a 10-second smoke test. If it fails, the call is skipped and an incident is recorded — no more 10-minute hangs waiting for a broken Codex session.

### stderr Separation + Exit Code Taxonomy

Codex stdout and stderr are now captured to separate files. stderr is scanned for auth/error patterns.

Exit codes are now meaningful:
- `0` — success
- `1` — CLI missing or general failure
- `2` — timeout (DEGRADED)
- `3` — signal killed
- `4` — auth failure (NEW)
- `5` — preflight failure (NEW)
- `6` — stall detected (NEW)

### Haiku Monitor Agent (`agents/bmb-monitor.md`)

A new **Lead-owned lightweight observer** agent that watches agent metadata and reports state changes to Lead — without doing any work.

| Property | Value |
|----------|-------|
| **Model** | Claude Haiku (lowest cost) |
| **Tools** | Bash (metadata-only), SendMessage, Read (first 5 lines only) |
| **Owner** | Lead — not a standalone worker |
| **Purpose** | Stall detection, timeout warnings, process liveness checks |

**Key design constraints:**
- **Metadata-only**: Bash commands restricted to `test -f`, `stat`, `wc -c`, `ls -l`, `ps -p`. No `cat`, `grep`, or content reads.
- **Stall detection**: Flags when a process is alive but file metadata has been unchanged for `idle_stall_sec` (default 180s).
- **Blind phase filtering**: During testing/verification, Monitor reports lifecycle events to Consultant but **never transmits** test verdicts, failure details, or coverage numbers.
- **Optional dependency**: Monitor failure never blocks the pipeline. If it crashes mid-run, Lead continues; existing polling handles timeouts.

**Watch item registration** — Lead sends JSON schema to Monitor at agent spawn:
```json
{
  "agent": "tester-claude",
  "step": "6",
  "result_path": ".bmb/handoffs/test-result-claude.md",
  "timeout_sec": 1200,
  "blind_phase": true
}
```

Monitor reports state changes in this format:
```
[MONITOR] agent=tester-claude step=6 state=stalled idle_sec=185 cpu_pct=0.1 ts=14:22
```

---

## Files Changed

| File | What Changed |
|------|-------------|
| `skills/bmb/bmb.md` | Step 11 → Retrospective (11.1–11.5), Step 12 → Cleanup |
| `scripts/cross-model-run.sh` | `timeout` fallback, preflight check, stderr separation, refined exit codes |
| `config/defaults.json` | `retrospective.min_learnings_per_session: 1`, `cross_model.preflight_timeout: 10` |
| `agents/bmb-analyst.md` | Lead-relay summary section added to report template |
| `agents/bmb-monitor.md` | **New** — Haiku Monitor agent (Lead-owned observer, metadata-only stall detection) |

---

## Upgrade Notes

No manual migration required. The retrospective substeps (11.1–11.5) are enforced by the updated `skills/bmb/bmb.md`. Install the latest version:

```bash
curl -fsSL https://raw.githubusercontent.com/project820/be-my-butler/main/install.sh | bash
bmb doctor
```

---

[Full Changelog](CHANGELOG.md) | [Architecture Docs](https://project820.github.io/be-my-butler/)
