#!/usr/bin/env bash
# auto-evolve daemon for tmux %0 — subagent 自进化无人值守闭环
# 运行在 tmux %0 的 pi 会话中，演示：修改 -> test -> /reload -> capture-pane -> 下一迭代
# 使用：nohup bash xdg_config/pi/agent/extensions/subagent/auto-evolve.sh >/tmp/auto-evolve.out 2>&1 &
set -euo pipefail

LOG=/tmp/auto-evolve.log
CAPTURE_DIR=/tmp
PANE="%0"
INTERVAL_SEC=90  # 每 90s 一轮，避免与模型思考冲突
REPO_DIR=/Users/liu/tools/dotfiles

handle_signal() {
  local signal="$1"
  echo "[$(date -Iseconds)] trap received ${signal}, exiting gracefully" | tee -a "$LOG"
  exit 0
}

trap 'handle_signal TERM' TERM
trap 'handle_signal INT' INT

echo "[$(date -Iseconds)] auto-evolve daemon started, interval=${INTERVAL_SEC}s, pane=${PANE}" | tee -a "$LOG"
echo "[$(date -Iseconds)] git diff --stat snapshot:" | tee -a "$LOG"
git_stat="$(git -C "$REPO_DIR" diff --stat 2>&1 || true)"
if [ -n "$git_stat" ]; then
  printf '%s\n' "$git_stat" | tee -a "$LOG"
else
  echo "(no git diff --stat output)" | tee -a "$LOG"
fi

iter=0
while true; do
  iter=$((iter+1))
  echo "[$(date -Iseconds)] === iter $iter: waiting ${INTERVAL_SEC}s ===" | tee -a "$LOG"
  sleep "$INTERVAL_SEC"

  # 若 pi 仍在 RUNNING/STREAMING，则跳过本轮，并记录 capture 上下文便于审计
  pane_snapshot="$(tmux capture-pane -p -t "$PANE" 2>/dev/null || true)"
  if grep -qE "RUNNING TOOLS|STREAMING" <<< "$pane_snapshot"; then
    echo "[$(date -Iseconds)] pi busy, skip reload this round; busy context:" | tee -a "$LOG"
    grep -E "RUNNING TOOLS|STREAMING" <<< "$pane_snapshot" | tail -n 5 | tee -a "$LOG" || true
    continue
  fi

  echo "[$(date -Iseconds)] sending /reload" | tee -a "$LOG"
  tmux send-keys -t "$PANE" "/reload" Enter
  sleep 3
  tmux capture-pane -p -t "$PANE" 2>/dev/null | tail -n 30 >> "$LOG"
  echo "[$(date -Iseconds)] capture after reload:" | tee -a "$LOG"
  grep -E "Reloaded|idle|holds|✓|✗" /tmp/auto-evolve.log | tail -n 5 | tee -a "$LOG" || true

  # 每 2 轮发送一次继续提示词，触发父模型下一进化（若父模型空闲）
  if [ $((iter % 2)) -eq 0 ]; then
    pane_snapshot="$(tmux capture-pane -p -t "$PANE" 2>/dev/null || true)"
    if ! grep -qE "RUNNING TOOLS|STREAMING" <<< "$pane_snapshot"; then
      echo "[$(date -Iseconds)] sending continuation prompt" | tee -a "$LOG"
      # 使用普通文本而非 slash 命令，避免误触发
      tmux send-keys -t "$PANE" "yes go — auto evolve continue (daemon iter $iter)" Enter
    else
      echo "[$(date -Iseconds)] pi busy, skip continuation prompt; busy context:" | tee -a "$LOG"
      grep -E "RUNNING TOOLS|STREAMING" <<< "$pane_snapshot" | tail -n 5 | tee -a "$LOG" || true
    fi
  fi

  # 演示：每 3 轮起一个 background demo（验证 widget）
  if [ $((iter % 3)) -eq 0 ]; then
    pane_snapshot="$(tmux capture-pane -p -t "$PANE" 2>/dev/null || true)"
    if ! grep -qE "RUNNING TOOLS|STREAMING" <<< "$pane_snapshot"; then
      echo "[$(date -Iseconds)] triggering demo subagent" | tee -a "$LOG"
      tmux send-keys -t "$PANE" "请启动一个 background scout 演示 widget（auto iter $iter）" Enter
    else
      echo "[$(date -Iseconds)] pi busy, skip demo subagent; busy context:" | tee -a "$LOG"
      grep -E "RUNNING TOOLS|STREAMING" <<< "$pane_snapshot" | tail -n 5 | tee -a "$LOG" || true
    fi
  fi

  # 安全退出：跑 10 轮后结束，避免无限打扰
  if [ "$iter" -ge 10 ]; then
    echo "[$(date -Iseconds)] daemon completed 10 轮, exiting; git diff --stat snapshot before stop:" | tee -a "$LOG"
    git -C "$REPO_DIR" diff --stat 2>&1 | tee -a "$LOG" || true
    echo "[$(date -Iseconds)] 重启: nohup bash xdg_config/pi/agent/extensions/subagent/auto-evolve.sh >/tmp/auto-evolve.out 2>&1 &" | tee -a "$LOG"
    break
  fi
done
