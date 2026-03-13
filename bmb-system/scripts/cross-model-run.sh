#!/bin/bash
# BMB-System Cross-Model Wrapper
# Single source of truth for cross-model invocation.
# ALL cross-model invocations in the pipeline MUST use this script.
# Supports: Codex, Gemini CLI
#
# Usage: cross-model-run.sh [--profile PROFILE] 'prompt here'
# Profiles: council (read-only), verify (read-only), review (plan critique), test (test files), exec-assist (write)

set -euo pipefail

# --- Parse arguments ---
PROFILE="exec-assist"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    *) break ;;
  esac
done
PROMPT="${1:?Usage: cross-model-run.sh [--profile PROFILE] 'prompt here'}"

# --- Resolve config ---
BMB_DIR="${BMB_DIR:-.bmb}"
CONFIG_FILE="${BMB_DIR}/config.json"

# Read provider from config.json → env var → default "codex"
if [ -f "$CONFIG_FILE" ] && command -v python3 &>/dev/null; then
  PROVIDER=$(python3 -c "
import json, sys
try:
    c = json.load(open('$CONFIG_FILE'))
    print(c.get('cross_model',{}).get('provider','codex'))
except: print('codex')
" 2>/dev/null) || PROVIDER="codex"
else
  PROVIDER="${BMB_CROSS_MODEL_PROVIDER:-codex}"
fi

# Read model override from config (empty = use CLI default i.e. LATEST)
MODEL_OVERRIDE=""
if [ -f "$CONFIG_FILE" ] && command -v python3 &>/dev/null; then
  MODEL_OVERRIDE=$(python3 -c "
import json
try:
    c = json.load(open('$CONFIG_FILE'))
    cm = c.get('cross_model',{})
    key = '${PROVIDER}_model'
    v = cm.get(key, 'LATEST')
    print('' if v == 'LATEST' else v)
except: print('')
" 2>/dev/null) || MODEL_OVERRIDE=""
fi

# Read timeout from config
if [ -f "$CONFIG_FILE" ] && command -v python3 &>/dev/null; then
  TIMEOUT=$(python3 -c "
import json
try:
    c = json.load(open('$CONFIG_FILE'))
    print(c.get('cross_model',{}).get('timeout_seconds', 3600))
except: print(3600)
" 2>/dev/null) || TIMEOUT=3600
else
  TIMEOUT=3600
fi

WORKDIR="${BMB_WORKDIR:-$(pwd)}"

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

# --- Invoke provider ---
case "$PROVIDER" in
  codex)
    if ! command -v codex &>/dev/null; then
      echo "ERROR: codex CLI not found. Install or switch provider in config." >&2
      echo "DEGRADED: Cross-model unavailable, proceeding Claude-only" >&2
      exit 1
    fi
    MODEL_ARGS=""
    if [ -n "$MODEL_OVERRIDE" ]; then
      MODEL_ARGS="-m $MODEL_OVERRIDE"
    fi
    exec codex exec $MODEL_ARGS --full-auto -C "$WORKDIR" "$FULL_PROMPT"
    ;;

  gemini)
    if ! command -v gemini &>/dev/null; then
      echo "ERROR: gemini CLI not found. Install or switch provider in config." >&2
      echo "DEGRADED: Cross-model unavailable, proceeding Claude-only" >&2
      exit 1
    fi
    MODEL_ARGS=""
    if [ -n "$MODEL_OVERRIDE" ]; then
      MODEL_ARGS="-m $MODEL_OVERRIDE"
    fi
    exec gemini run $MODEL_ARGS "$FULL_PROMPT"
    ;;

  *)
    echo "ERROR: Unknown provider '$PROVIDER'. Use 'codex' or 'gemini'." >&2
    exit 1
    ;;
esac
