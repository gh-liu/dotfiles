# auto-evolve extension

Conditionally-registered control tools + a lightweight skill for driving the
existing `auto-evolve.sh` daemon from a Pi session that has an
**independent worker pane** running Pi inside this repository.

The extension lives at `xdg_config/pi/agent/extensions/auto-evolve/` and is
auto-discovered by pi (directory extension with `index.ts`).

## Design decisions

- **Conditional registration.** On `session_start` the extension probes the
  current tmux session (`tmux list-panes -t <current-session>`) for panes that
  (1) are not the current pane, (2) run `pi`/`node`/`nodejs`/`bun` (basename
  match, so `/usr/bin/pi` counts), and (3) have their cwd inside this repository
  (safe prefix check: `/home/liu/repo2` does not match repo root `/home/liu/repo`).
  Only when at least one candidate exists are the three tools
  (`auto_evolve_status` / `auto_evolve_start` / `auto_evolve_stop`) and the
  skill registered.
- **Silent without tmux / worker.** No tmux or no candidate → zero registration,
  zero `notify`, zero side effects; only a single debug log line is written.
  The same `session_start` handler ignores `event.reason` (`startup`/`reload`/…),
  so probing happens identically on every session start.
- **Simplified probing.** The current pane comes from `$TMUX_PANE` when set,
  with a `tmux display-message -p '#{pane_id}'` fallback. The current session is
  resolved the same way and only that session is scanned (no cross-session).
  tmux's literal `\t` in `-F` output is normalized before splitting
  (`parsePanesOutput`), mirroring `auto-evolve.sh`.
- **Shared evolve log contract.** Every driven work unit must record each
  iteration's goal, evidence, changes, validation, and risks in the agent-level
  log `xdg_config/pi/agent/evolve/EVOLVE_LOG.md` (one `Iteration N` heading per
  round) rather than writing an evolution log back into the evolved object's
  own directory.
- **Stable per-pane stop file.** `<agent-dir>/auto-evolve.<sanitized-pane>.stop`
  (e.g. `%41` → `auto-evolve._41.stop`) is derived once and shared between
  start and stop, so the daemon's graceful exit signal always targets the right
  file.
- **Self-snapshot immunity.** The daemon re-execs from a stable snapshot copy
  (`cp` + `exec bash <snapshot>`) taken at the very top of `auto-evolve.sh`, so
  self-evolution rewrites of the workspace script no longer crash the streamed
  script mid-run (previously `syntax error near unexpected token` killed the
  unattended loop and left the stop file stale). The snapshot keeps the
  `auto-evolve.sh` basename so `pgrep -f "auto-evolve.sh <pane>"` discovery
  still matches, `SCRIPT_DIR`/`AGENT_DIR` are pinned via env so the stop-file /
  log protocol never shifts, and the snapshot dir is overridable with
  `AUTO_EVOLVE_SNAPSHOT_DIR` (default `<tmp>/auto-evolve-snapshot/<pid>`, cleaned
  on EXIT).
- **Injected side effects.** `daemon.ts` takes `spawn`/`exec`/`touch`/
  `readLogTail` as parameters and `probe.ts` is pure, so unit tests never touch
  a real tmux session, process, or file. `repoRoot` is resolved lazily via
  `getRepoRoot(exec)` (git toplevel of the extensions dir) rather than at module
  load, keeping module import side-effect free.

## Usage

In a Pi session that has a worker pane running Pi inside this repo, the **main agent**
decides what to evolve and passes it as `target` to `auto_evolve_start`; there is no default
target (the daemon no longer hardcodes `subagent`).

1. `auto_evolve_status` — candidate panes + per-pane daemon status + log path.
2. `auto_evolve_start [pane] target=<work-unit>` — spawn the unattended daemon; returns
   `{ runId (timestamp), paneId, target, pid, stopFile, logPath }`. Pane must be in the
   probed whitelist; defaults to the first candidate; refuses duplicates
   (`already-running`). `target` is **required** and decided by the main agent: it names the
   bounded work unit the daemon tells the worker Pi to keep improving. There is no built-in
   default target (previously it hardcoded `subagent`).
3. `auto_evolve_stop [pane]` — touch the stable stop file + SIGTERM; returns
   the stopped pane and actions taken.

The `skill/SKILL.md` explains when the strategy applies and the guardrails
(scope, small verifiable steps, shared agent-level evolve log at
`xdg_config/pi/agent/evolve/EVOLVE_LOG.md`, stop-file protocol, one daemon per pane).

## Files

- `probe.ts` — pure parsing / filtering / pane + session detection
- `daemon.ts` — daemon lifecycle (start / stop / status), injected side effects
- `index.ts` — extension entry point, conditional registration
- `skill/SKILL.md` — strategy skill contributed via `resources_discover`
- `probe.test.ts`, `daemon.test.ts`, `index.test.ts` — vitest unit tests
- `tsconfig.json` — mirrors `subagent/tsconfig.json`

## Validation

```bash
npx tsc -p xdg_config/pi/agent/extensions/auto-evolve/tsconfig.json
npm test --prefix xdg_config/pi/agent/extensions
```

`npm test` runs `typecheck:subagent && typecheck:context && typecheck:auto-evolve
&& vitest run`, so existing subagent/context tests must keep passing.

## Risks & rollback

- **Rollback**: delete `xdg_config/pi/agent/extensions/auto-evolve/` and revert
  the single `package.json` scripts edit (`typecheck:auto-evolve` + the `test`
  chain). Because the extension registers nothing unless a worker pane exists,
  removing it is side-effect free.
- **Unattended daemon**: `auto_evolve_start` spawns a detached, self-driving
  daemon; it only stops via the stop-file protocol or its safety attempt limit.
  Always call `auto_evolve_stop` when done. Never add `ctx.reload` /
  `ctx.shutdown` / `sendUserMessage` calls — the tools only manage the external
  daemon.
- **Stale registration**: tools are registered once per extension instance; if a
  later `session_start` (e.g. reload) finds no candidates, previously registered
  tools remain but throw `no worker pane candidates probed in this session`
  instead of acting — a safe fail-closed state.
- **Mode behavior**: probing is tmux-based, not UI-based, so tools may appear in
  any mode (`tui`/`rpc`/`json`/`print`) whenever a worker pane exists; `notify`
  is fire-and-forget and a no-op without UI. RPC sessions without a tmux worker
  register nothing, as designed.
- **Known limits**: candidates are only the current session; the daemon script
  itself is unchanged (out of scope); status "active" is a heuristic based on
  the last log line's timestamp within a 5-minute window; the status tool's
  `logTail` snapshot is bounded (`STATUS_LOG_TAIL_MAX_BYTES`, 2KB/pane) to keep
  context cheap, with the full daemon log available at `logPath`.