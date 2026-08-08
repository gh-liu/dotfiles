#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
extension="$script_dir/index.ts"
runtime_dir=$(mktemp -d /tmp/pi-archive-tui.XXXXXX)
config_dir="$runtime_dir/pi-config"
session="$runtime_dir/session.jsonl"
tmux_config="$runtime_dir/tmux.conf"
tmux_socket="pi-archive-tui-$$"
tmux_session="pi"
artifact_dir=${PI_TUI_ARTIFACT_DIR:-"$runtime_dir/artifacts"}
keep_artifacts=false

if [[ -n ${PI_TUI_ARTIFACT_DIR:-} ]]; then
  mkdir -p "$artifact_dir"
  keep_artifacts=true
fi

cleanup() {
  tmux -L "$tmux_socket" kill-server 2>/dev/null || true
  rm -rf "$runtime_dir"
}
trap cleanup EXIT

for command in pi tmux jq; do
  if ! command -v "$command" >/dev/null; then
    echo "Missing required command: $command" >&2
    exit 1
  fi
done

mkdir -p "$config_dir" "$artifact_dir"
cat >"$tmux_config" <<'EOF'
set -g extended-keys on
set -g extended-keys-format csi-u
EOF

cat >"$session" <<'EOF'
{"type":"session","version":3,"id":"archive-tui-e2e","timestamp":"2026-08-07T00:00:00.000Z","cwd":"/Users/liu/tools/dotfiles"}
{"type":"message","id":"A","parentId":null,"timestamp":"2026-08-07T00:00:01.000Z","message":{"role":"user","content":[{"type":"text","text":"root"}],"timestamp":1786032001000}}
{"type":"message","id":"B","parentId":"A","timestamp":"2026-08-07T00:00:02.000Z","message":{"role":"user","content":[{"type":"text","text":"current-branch"}],"timestamp":1786032002000}}
{"type":"message","id":"C","parentId":"A","timestamp":"2026-08-07T00:00:03.000Z","message":{"role":"user","content":[{"type":"text","text":"other-branch"}],"timestamp":1786032003000}}
{"type":"message","id":"D","parentId":"B","timestamp":"2026-08-07T00:00:04.000Z","message":{"role":"user","content":[{"type":"text","text":"current-leaf"}],"timestamp":1786032004000}}
EOF

capture() {
  tmux -L "$tmux_socket" capture-pane -p -t "$tmux_session" -S -100
}

snapshot() {
  local name=$1
  capture >"$artifact_dir/$name.txt"
  tmux -L "$tmux_socket" capture-pane -p -e -t "$tmux_session" -S -100 \
    >"$artifact_dir/$name.ansi"
}

wait_for() {
  local expected=$1
  local attempts=100
  while ((attempts-- > 0)); do
    if capture 2>/dev/null | grep -Fq -- "$expected"; then
      return
    fi
    if ! tmux -L "$tmux_socket" has-session -t "$tmux_session" 2>/dev/null; then
      echo "pi exited while waiting for: $expected" >&2
      return 1
    fi
    sleep 0.1
  done
  echo "Timed out waiting for: $expected" >&2
  capture >&2 || true
  return 1
}

send() {
  tmux -L "$tmux_socket" send-keys -t "$tmux_session" "$@"
}

archive_entry_count() {
  jq -s '[.[] | select(.type == "custom" and .customType == "branch-archive")] | length' \
    "$session"
}

backup_count() {
  find "$runtime_dir" -maxdepth 1 -name '.pi-archive-*.bak' -type f | wc -l | tr -d ' '
}

tmux -L "$tmux_socket" -f "$tmux_config" new-session \
  -d \
  -s "$tmux_session" \
  -x 120 \
  -y 40 \
  "PI_CODING_AGENT_DIR='$config_dir' PI_OFFLINE=1 pi \
    --no-extensions \
    --no-skills \
    --no-prompt-templates \
    --no-themes \
    --no-context-files \
    --offline \
    --tui-mode regular \
    --session '$session' \
    -e '$extension'"

wait_for 'current-leaf'
send '/archive' Enter
wait_for 'Archive Branches'
snapshot 01-archive-open

send Space
wait_for 'The current branch cannot be archived'
snapshot 02-current-branch-denied
test "$(archive_entry_count)" -eq 0

send Down Space
wait_for 'Branch archived'
snapshot 03-other-branch-archived
archived_picker=$(capture)
grep -Fq 'Archive Branches' <<<"$archived_picker"
grep -Fq 'user: other-branch  archived' <<<"$archived_picker"
test "$(archive_entry_count)" -eq 1
test "$(backup_count)" -eq 1
test "$(jq -r 'select(.customType == "branch-archive") | .parentId' "$session")" = A
resumed_before=$(grep -Fc 'Resumed session' <<<"$archived_picker" || true)

send Space
wait_for 'Branch restored'
snapshot 04-other-branch-restored-in-place
restored_picker=$(capture)
grep -Fq 'Archive Branches' <<<"$restored_picker"
test "$(archive_entry_count)" -eq 0
test "$(backup_count)" -eq 1
test "$(grep -Fc 'Resumed session' <<<"$restored_picker" || true)" -eq "$resumed_before"

send Space
wait_for 'Branch archived'
snapshot 05-other-branch-rearchived-in-place
rearchived_picker=$(capture)
grep -Fq 'Archive Branches' <<<"$rearchived_picker"
grep -Fq 'user: other-branch  archived' <<<"$rearchived_picker"
test "$(archive_entry_count)" -eq 1
test "$(backup_count)" -eq 1
test "$(grep -Fc 'Resumed session' <<<"$rearchived_picker" || true)" -eq "$resumed_before"

send Escape
sleep 0.2
test "$(backup_count)" -eq 0
send '/tree' Enter
wait_for 'Session Tree'
send C-a
sleep 0.2
snapshot 06-tree-all-archived
tree_archived=$(capture)
test "$(awk '/\[custom: branch-archive\]/{count++} END{print count+0}' <<<"$tree_archived")" -eq 1
if grep -Fq 'user: other-branch' <<<"$tree_archived"; then
  echo 'Archived branch is still visible in /tree all' >&2
  exit 1
fi

send 'branch-archive' Enter
sleep 0.2
if capture | grep -Fq 'Summarize branch?'; then
  send Enter
fi
wait_for 'Use /archive to restore this branch'
snapshot 07-tree-archive-navigation-blocked
test "$(archive_entry_count)" -eq 1

sleep 0.2
send '/archive' Enter
wait_for 'Archive Branches'
send Down Enter
wait_for 'other-branch'
sleep 0.2
snapshot 08-enter-restores-and-navigates
test "$(archive_entry_count)" -eq 0
test "$(backup_count)" -eq 0
if capture | grep -Fq 'Archive Branches'; then
  echo 'Archive picker remained open after Enter navigation' >&2
  exit 1
fi

echo 'Archive TUI E2E passed with isolated default Pi configuration'
if $keep_artifacts; then
  echo "Terminal snapshots: $artifact_dir"
fi
