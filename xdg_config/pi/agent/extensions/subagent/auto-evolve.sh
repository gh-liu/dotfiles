#!/usr/bin/env bash
# Bounded auto-evolve loop for an explicitly selected Pi tmux pane.
# Usage: bash auto-evolve.sh <pane-id> (or set PANE).
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${REPO_DIR:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)}"
AGENT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG="${AUTO_EVOLVE_LOG:-$AGENT_DIR/auto-evolve.log}"
PANE="${PANE:-${1:-}}"
INTERVAL_SEC="${INTERVAL_SEC:-90}"
RELOAD_DELAY_SEC="${RELOAD_DELAY_SEC:-3}"
SAFETY_MAX_ATTEMPTS="${SAFETY_MAX_ATTEMPTS:-100}"
RUN_ID="$(date +%s)-$$"
STOP_FILE="${AUTO_EVOLVE_STOP_FILE:-$AGENT_DIR/auto-evolve.$RUN_ID.stop}"

if [[ -z "$PANE" ]]; then
  echo "Usage: $0 <tmux-pane-id> (or set PANE)" >&2
  exit 2
fi
if [[ ! "$INTERVAL_SEC" =~ ^[0-9]+$ || ! "$RELOAD_DELAY_SEC" =~ ^[0-9]+$ || ! "$SAFETY_MAX_ATTEMPTS" =~ ^[1-9][0-9]*$ ]]; then
  echo "INTERVAL_SEC and RELOAD_DELAY_SEC must be non-negative; SAFETY_MAX_ATTEMPTS must be a positive integer" >&2
  exit 2
fi

mkdir -p "$(dirname "$LOG")"

log() {
  echo "[$(date -Iseconds)] $*" | tee -a "$LOG"
}

validate_pane() {
  local metadata pane_pid pane_command pane_path
  if ! metadata="$(tmux display-message -p -t "$PANE" '#{pane_pid}	#{pane_current_command}	#{pane_current_path}' 2>/dev/null)"; then
    log "refusing input: tmux pane $PANE does not exist"
    return 1
  fi
  # tmux format strings preserve \t literally; normalize before splitting.
  metadata="${metadata//\\t/$'\t'}"
  IFS=$'\t' read -r pane_pid pane_command pane_path <<< "$metadata"
  if [[ -z "$pane_pid" || ! "$pane_command" =~ ^(pi|node|nodejs|bun)$ ]]; then
    log "refusing input: pane $PANE command '$pane_command' is not a supported Pi runtime"
    return 1
  fi
  case "$pane_path" in
    "$REPO_DIR"|"$REPO_DIR"/*) ;;
    *)
      log "refusing input: pane $PANE cwd '$pane_path' is outside '$REPO_DIR'"
      return 1
      ;;
  esac
}

capture_pane() {
  validate_pane
  tmux capture-pane -p -t "$PANE"
}

send_text() {
  local text="$1"
  validate_pane
  tmux send-keys -t "$PANE" -l "$text"
  validate_pane
  tmux send-keys -t "$PANE" Enter
}

handle_signal() {
  rm -f "$STOP_FILE"
  log "trap received $1, exiting gracefully"
  exit 0
}

trap 'handle_signal TERM' TERM
trap 'handle_signal INT' INT

validate_pane
printf -v quoted_stop_file '%q' "$STOP_FILE"
log "auto-evolve daemon started, interval=${INTERVAL_SEC}s, safety-max=${SAFETY_MAX_ATTEMPTS}, pane=${PANE}"
log "the model controls completion via stop signal: $STOP_FILE"
log "git diff --stat snapshot:"
git_stat="$(git -C "$REPO_DIR" diff --stat 2>&1 || true)"
if [[ -n "$git_stat" ]]; then
  printf '%s\n' "$git_stat" | tee -a "$LOG"
else
  echo "(no git diff --stat output)" | tee -a "$LOG"
fi

stop_reason="safety limit reached"
attempts_run=0
for ((attempt = 1; attempt <= SAFETY_MAX_ATTEMPTS; attempt++)); do
  attempts_run="$attempt"
  log "=== attempt $attempt: waiting ${INTERVAL_SEC}s ==="
  sleep "$INTERVAL_SEC"

  if [[ -f "$STOP_FILE" ]]; then
    stop_reason="model marked evolution complete"
    break
  fi

  pane_snapshot="$(capture_pane)"
  if grep -qE "RUNNING TOOLS|STREAMING" <<< "$pane_snapshot"; then
    log "pi busy, skip reload this round; busy context:"
    grep -E "RUNNING TOOLS|STREAMING" <<< "$pane_snapshot" | tail -n 5 | tee -a "$LOG" || true
    continue
  fi

  log "sending /reload"
  send_text "/reload"
  sleep "$RELOAD_DELAY_SEC"
  capture_pane | tail -n 30 >> "$LOG"
  log "capture after reload:"
  grep -E "Reloaded|idle|holds|✓|✗" "$LOG" | tail -n 5 | tee -a "$LOG" || true

  pane_snapshot="$(capture_pane)"
  if ! grep -qE "RUNNING TOOLS|STREAMING" <<< "$pane_snapshot"; then
    log "asking model to continue or mark completion"
    send_text "请评估 subagent 是否还有高价值、可验证的改进。若有则继续一轮；若已完成，请运行：touch $quoted_stop_file"
  else
    log "pi busy, skip model decision prompt; busy context:"
    grep -E "RUNNING TOOLS|STREAMING" <<< "$pane_snapshot" | tail -n 5 | tee -a "$LOG" || true
  fi

  if ((attempt % 3 == 0)); then
    pane_snapshot="$(capture_pane)"
    if ! grep -qE "RUNNING TOOLS|STREAMING" <<< "$pane_snapshot"; then
      log "triggering demo subagent"
      send_text "请启动一个 background scout 演示 widget（auto attempt $attempt）"
    else
      log "pi busy, skip demo subagent; busy context:"
      grep -E "RUNNING TOOLS|STREAMING" <<< "$pane_snapshot" | tail -n 5 | tee -a "$LOG" || true
    fi
  fi
done

rm -f "$STOP_FILE"
log "daemon stopped: ${stop_reason}; attempts=${attempts_run}; git diff --stat snapshot before stop:"
git -C "$REPO_DIR" diff --stat 2>&1 | tee -a "$LOG" || true
log "restart explicitly with: bash xdg_config/pi/agent/extensions/subagent/auto-evolve.sh '$PANE'"
