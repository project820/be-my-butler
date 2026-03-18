#!/bin/bash
# BMB-System Cross-Model Wrapper
# Single source of truth for cross-model invocation.
# ALL cross-model invocations in the pipeline MUST use this script.
# Supports: Codex, Gemini CLI
#
# Usage: cross-model-run.sh [--profile PROFILE] 'prompt here'
# Profiles: council (read-only), verify (read-only), review (plan critique), test (test files), exec-assist (write)
#
# Exit codes:
#   0 = success
#   1 = CLI not found / general failure (DEGRADED)
#   2 = timeout (DEGRADED)
#   3 = process hung/killed (DEGRADED)
#   4 = auth failure (401/unauthorized detected)
#   5 = preflight failure (provider CLI broken before invocation)
#   6 = stall detected (process alive but no output for N seconds)

# --- Portable timeout fallback (macOS ships without coreutils timeout) ---
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

set -euo pipefail

# --- Parse arguments ---
PROFILE="exec-assist"
OUTPUT_FILE=""
USE_STDIN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    -o) OUTPUT_FILE="$2"; shift 2 ;;
    -) USE_STDIN=true; shift ;;
    *) break ;;
  esac
done

# If stdin mode, read prompt from stdin; otherwise require positional arg
if [ "$USE_STDIN" = true ]; then
  PROMPT="$(cat)"
else
  PROMPT="${1:?Usage: cross-model-run.sh [--profile PROFILE] [-o OUTPUT_FILE] [-] 'prompt here'}"
fi

# --- Resolve config (provider, model, timeout) in one pass ---
BMB_DIR="${BMB_DIR:-.bmb}"
CONFIG_FILE="${BMB_DIR}/config.json"

PROVIDER="${BMB_CROSS_MODEL_PROVIDER:-codex}"
MODEL_OVERRIDE=""
TIMEOUT=3600

if [ -f "$CONFIG_FILE" ] && command -v python3 &>/dev/null; then
  _CFG_LINE=$(_BMB_CFG="$CONFIG_FILE" python3 << 'PYEOF'
import json, os
try:
    c = json.load(open(os.environ['_BMB_CFG']))
    cm = c.get('cross_model', {})
    provider = cm.get('provider', 'codex')
    model_key = provider + '_model'
    model = cm.get(model_key, 'LATEST')
    model_out = '' if model == 'LATEST' else model
    timeout = cm.get('timeout_seconds', 3600)
    print(f"{provider}\t{model_out}\t{timeout}")
except:
    print("codex\t\t3600")
PYEOF
  ) || _CFG_LINE=""
  if [ -n "$_CFG_LINE" ]; then
    PROVIDER=$(echo "$_CFG_LINE" | cut -f1)
    MODEL_OVERRIDE=$(echo "$_CFG_LINE" | cut -f2)
    TIMEOUT=$(echo "$_CFG_LINE" | cut -f3)
  fi
fi

WORKDIR="${BMB_WORKDIR:-$(pwd)}"

# --- Profile-based default timeouts (v0.3.4) ---
# Override main TIMEOUT with profile-specific defaults, then config override
_PROFILE_TIMEOUT=""
case "$PROFILE" in
  council)     _PROFILE_TIMEOUT=600 ;;
  verify)      _PROFILE_TIMEOUT=600 ;;
  review)      _PROFILE_TIMEOUT=600 ;;
  test)        _PROFILE_TIMEOUT=1200 ;;
  exec-assist) _PROFILE_TIMEOUT=3600 ;;
esac

# Config override: timeouts.{profile} key takes precedence
if [ -f "$CONFIG_FILE" ] && command -v python3 &>/dev/null; then
  _PROF_CFG=$(_BMB_CFG="$CONFIG_FILE" _BMB_PROF="$PROFILE" python3 << 'PYEOF'
import json, os
try:
    c = json.load(open(os.environ['_BMB_CFG']))
    t = c.get('timeouts', {})
    prof = os.environ.get('_BMB_PROF', '')
    # Check profile-specific key first, then targeted re-test/re-verify
    val = t.get(prof, t.get(f'cross_model_{prof}', ''))
    if val: print(val)
except:
    pass
PYEOF
  ) || _PROF_CFG=""
  if [ -n "$_PROF_CFG" ]; then
    _PROFILE_TIMEOUT="$_PROF_CFG"
  fi
fi

# Apply profile timeout if set
if [ -n "$_PROFILE_TIMEOUT" ]; then
  TIMEOUT="$_PROFILE_TIMEOUT"
fi

# --- Incident spool helper ---
BMB_INCIDENTS_SCRIPT="$HOME/.claude/bmb-system/scripts/bmb-external-incidents.sh"
_bmb_record_incident() {
  if [ -f "$BMB_INCIDENTS_SCRIPT" ]; then
    # shellcheck disable=SC1090
    source "$BMB_INCIDENTS_SCRIPT"
    bmb_incidents_record "$@"
  fi
}

# --- Profile-based permission prefix ---
PERM_PREFIX=""
case "$PROFILE" in
  council|verify)
    PERM_PREFIX="IMPORTANT: You are in READ-ONLY mode. Do NOT modify any source files. Only write to .bmb/ directory. " ;;
  review)
    PERM_PREFIX="IMPORTANT: You are reviewing a plan document. Provide thorough critique: design flaws, missing considerations, infeasible parts, security vulnerabilities, and runtime contract conflicts. Output findings-first markdown. " ;;
  test)
    PERM_PREFIX="IMPORTANT: You may only create/modify test files. Do NOT modify source/production code. Write results to .bmb/ directory. " ;;
  exec-assist)
    PERM_PREFIX="" ;;
  *)
    echo "ERROR: Unknown profile '$PROFILE'. Use: council, verify, review, test, exec-assist" >&2; exit 1 ;;
esac

# --- Context compression ---
COMPRESS_PREFIX=""
if [ "${BMB_COMPRESS_OUTPUT:-0}" = "1" ]; then
  COMPRESS_PREFIX="For any command output exceeding 50 lines, write full output to .bmb/.tool-cache/ and keep only a structured summary. "
fi

FULL_PROMPT="${PERM_PREFIX}${COMPRESS_PREFIX}${PROMPT}"

# --- Preflight check (v0.3.5) ---
# Verify provider CLI is functional before committing to a long invocation
_PREFLIGHT_TIMEOUT="${BMB_PREFLIGHT_TIMEOUT:-10}"
if [ -f "$CONFIG_FILE" ] && command -v python3 &>/dev/null; then
  _pf=$(_BMB_CFG="$CONFIG_FILE" python3 -c "
import json, os
try:
    c = json.load(open(os.environ['_BMB_CFG']))
    print(c.get('cross_model', {}).get('preflight_timeout', 10))
except:
    print(10)
" 2>/dev/null) || _pf=10
  _PREFLIGHT_TIMEOUT="$_pf"
fi

_codex_preflight() {
  if ! command -v codex &>/dev/null; then
    echo "PREFLIGHT FAIL: codex CLI not found" >&2
    _bmb_record_incident "codex_cli_missing" "profile=$PROFILE preflight=true" 1 "cross-model-run"
    return 1
  fi
  # Quick version check to verify CLI is responsive
  if ! timeout "$_PREFLIGHT_TIMEOUT" codex --version &>/dev/null; then
    echo "PREFLIGHT FAIL: codex --version timed out or failed" >&2
    _bmb_record_incident "codex_preflight_failed" "profile=$PROFILE timeout=${_PREFLIGHT_TIMEOUT}s" 5 "cross-model-run"
    return 1
  fi
  return 0
}

_gemini_preflight() {
  if ! command -v gemini &>/dev/null; then
    echo "PREFLIGHT FAIL: gemini CLI not found" >&2
    _bmb_record_incident "gemini_cli_missing" "profile=$PROFILE preflight=true" 1 "cross-model-run"
    return 1
  fi
  if ! timeout "$_PREFLIGHT_TIMEOUT" gemini --version &>/dev/null; then
    echo "PREFLIGHT FAIL: gemini --version timed out or failed" >&2
    _bmb_record_incident "gemini_preflight_failed" "profile=$PROFILE timeout=${_PREFLIGHT_TIMEOUT}s" 5 "cross-model-run"
    return 1
  fi
  return 0
}

# --- Invoke provider ---
case "$PROVIDER" in
  codex)
    if ! _codex_preflight; then
      echo "DEGRADED: Cross-model unavailable, proceeding Claude-only" >&2
      exit 5
    fi
    MODEL_ARGS=""
    if [ -n "$MODEL_OVERRIDE" ]; then
      MODEL_ARGS="-m $MODEL_OVERRIDE"
    fi

    # --- v0.3.4: timeout + stall detection + recovery-first ---
    # --- v0.3.5: stderr separation + auth detection + stall exit code ---
    _RECOVERY_ATTEMPTED=false
    _run_codex() {
      local attempt="${1:-1}"
      local output_tmp stderr_tmp
      if [ -n "$OUTPUT_FILE" ]; then
        output_tmp="${OUTPUT_FILE}.tmp.$$"
        stderr_tmp="${OUTPUT_FILE}.stderr.$$"
        # Stream stdout/stderr separately (v0.3.5)
        timeout "$TIMEOUT" codex exec $MODEL_ARGS --full-auto -C "$WORKDIR" "$FULL_PROMPT" > "$output_tmp" 2>"$stderr_tmp"
        local rc=$?

        # Check stderr for error patterns
        if [ -s "$stderr_tmp" ]; then
          if grep -qi '401\|auth\|unauthorized' "$stderr_tmp" 2>/dev/null; then
            _bmb_record_incident "codex_auth_401" "profile=$PROFILE attempt=$attempt" "$rc" "cross-model-run"
          fi
          if grep -qi 'rate.limit\|429\|too.many.requests' "$stderr_tmp" 2>/dev/null; then
            _bmb_record_incident "codex_rate_limit" "profile=$PROFILE attempt=$attempt" "$rc" "cross-model-run"
          fi
          # Keep stderr for debugging
          mv "$stderr_tmp" "${OUTPUT_FILE}.stderr" 2>/dev/null || true
        else
          rm -f "$stderr_tmp"
        fi

        if [ $rc -eq 0 ] && [ -s "$output_tmp" ]; then
          mv "$output_tmp" "$OUTPUT_FILE"
        else
          # Preserve partial output for debugging
          [ -f "$output_tmp" ] && mv "$output_tmp" "${OUTPUT_FILE}.partial" 2>/dev/null || true
        fi
        return $rc
      else
        exec timeout "$TIMEOUT" codex exec $MODEL_ARGS --full-auto -C "$WORKDIR" "$FULL_PROMPT"
      fi
    }

    # First attempt
    _run_codex 1
    _EXIT_CODE=$?

    # Classify and record
    if [ $_EXIT_CODE -eq 0 ]; then
      # Success
      :
    elif [ $_EXIT_CODE -eq 124 ]; then
      # timeout(1) exit code = 124
      _bmb_record_incident "codex_review_timeout" "profile=$PROFILE timeout=${TIMEOUT}s" $_EXIT_CODE "cross-model-run"
      echo "TIMEOUT: codex exceeded ${TIMEOUT}s (profile=$PROFILE)" >&2

      # Recovery-first: one bounded restart attempt
      if [ "$_RECOVERY_ATTEMPTED" = false ]; then
        _RECOVERY_ATTEMPTED=true
        _bmb_record_incident "codex_recovery_restart_attempted" "profile=$PROFILE retry=1" 0 "cross-model-run"
        echo "RECOVERY: attempting one bounded restart..." >&2

        # Use recovery_restart timeout (shorter)
        _recovery_timeout="${TIMEOUT}"
        if [ -f "$CONFIG_FILE" ] && command -v python3 &>/dev/null; then
          _recovery_timeout=$(_BMB_CFG="$CONFIG_FILE" python3 -c "
import json, os
try:
    c = json.load(open(os.environ['_BMB_CFG']))
    print(c.get('timeouts', {}).get('recovery_restart', 300))
except:
    print(300)
" 2>/dev/null) || _recovery_timeout=300
        fi
        TIMEOUT="$_recovery_timeout"

        _run_codex 2
        _EXIT_CODE=$?

        if [ $_EXIT_CODE -eq 0 ]; then
          _bmb_record_incident "dependency_login_recovered" "profile=$PROFILE recovery=restart" 0 "cross-model-run"
          exit 0  # recovery succeeded — not degraded
        else
          _bmb_record_incident "codex_recovery_restart_failed" "profile=$PROFILE exit=$_EXIT_CODE" $_EXIT_CODE "cross-model-run"
          echo "RECOVERY FAILED: degrading to Claude-only" >&2
        fi
      fi
      exit 2  # exit 2 = timeout (DEGRADED)

    elif [ $_EXIT_CODE -gt 128 ]; then
      # Killed by signal
      _bmb_record_incident "codex_exec_nonzero" "profile=$PROFILE signal=$((_EXIT_CODE - 128))" $_EXIT_CODE "cross-model-run"
      echo "KILLED: codex terminated by signal $((_EXIT_CODE - 128)) (profile=$PROFILE)" >&2
      exit 3  # exit 3 = process hung/killed (DEGRADED)

    else
      # General non-zero exit
      # Check stderr for auth failure (v0.3.5: stderr is now separated)
      if [ -n "$OUTPUT_FILE" ] && [ -f "${OUTPUT_FILE}.stderr" ]; then
        if grep -qi '401\|auth\|unauthorized' "${OUTPUT_FILE}.stderr" 2>/dev/null; then
          _bmb_record_incident "codex_auth_401" "profile=$PROFILE" $_EXIT_CODE "cross-model-run"
          exit 4  # exit 4 = auth failure
        fi
      fi
      # Fallback: check partial output for auth patterns
      if [ -n "$OUTPUT_FILE" ] && [ -f "${OUTPUT_FILE}.partial" ]; then
        if grep -qi '401\|auth\|unauthorized' "${OUTPUT_FILE}.partial" 2>/dev/null; then
          _bmb_record_incident "codex_auth_401" "profile=$PROFILE" $_EXIT_CODE "cross-model-run"
          exit 4  # exit 4 = auth failure
        fi
      fi
      _bmb_record_incident "codex_exec_nonzero" "profile=$PROFILE exit=$_EXIT_CODE" $_EXIT_CODE "cross-model-run"
      exit 1  # exit 1 = general failure (DEGRADED)
    fi

    exit $_EXIT_CODE
    ;;

  gemini)
    if ! _gemini_preflight; then
      echo "DEGRADED: Cross-model unavailable, proceeding Claude-only" >&2
      exit 5
    fi
    MODEL_ARGS=""
    if [ -n "$MODEL_OVERRIDE" ]; then
      MODEL_ARGS="-m $MODEL_OVERRIDE"
    fi
    if [ -n "$OUTPUT_FILE" ]; then
      timeout "$TIMEOUT" gemini run $MODEL_ARGS "$FULL_PROMPT" > "$OUTPUT_FILE" 2>&1
      _GEM_EXIT=$?
      if [ $_GEM_EXIT -eq 124 ]; then
        _bmb_record_incident "gemini_review_timeout" "profile=$PROFILE timeout=${TIMEOUT}s" $_GEM_EXIT "cross-model-run"
        exit 2
      elif [ $_GEM_EXIT -ne 0 ]; then
        _bmb_record_incident "gemini_exec_nonzero" "profile=$PROFILE exit=$_GEM_EXIT" $_GEM_EXIT "cross-model-run"
        exit 1
      fi
    else
      exec timeout "$TIMEOUT" gemini run $MODEL_ARGS "$FULL_PROMPT"
    fi
    ;;

  *)
    echo "ERROR: Unknown provider '$PROVIDER'. Use 'codex' or 'gemini'." >&2
    exit 1
    ;;
esac
