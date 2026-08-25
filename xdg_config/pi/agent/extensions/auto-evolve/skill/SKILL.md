# Auto-Evolve Skill

Strategy for continuously improving a bounded extension or work unit inside this
repository, supervised from an **independent Pi worker pane**.

## When to use

Use this when the user asks you to keep improving a specific bounded work unit
in this repository (for example the `subagent/` extension) over repeated
improvement rounds, and an independent worker pane is available:

- A separate tmux pane is already running Pi (`pi`, `node`, `nodejs`, or `bun`)
  with its working directory inside this repository, and
- that worker pane is visible in the **current tmux session** (the extension
  only scans the current session, not other sessions).

If no worker pane is available, the auto-evolve tools are **not registered**;
do not attempt to drive the daemon yourself with raw commands.

## Workflow (three steps)

1. **Start**: call `auto_evolve_start` (optionally pass `pane` to select a
   specific worker pane; it defaults to the first candidate). This spawns the
   unattended daemon `auto-evolve.sh` in the worker pane. The daemon
   periodically sends `/reload` to the worker Pi and asks it to continue
   improving or to mark the run complete via the stop-file protocol.
2. **Observe**: call `auto_evolve_status` regularly and read the daemon log
   tail (`logPath`, reported by the status tool) to track progress. The daemon
   is unattended — monitor it rather than assuming it works forever.
3. **Stop**: call `auto_evolve_stop` when the improvement is complete, blocked,
   or exceeds the requested bound. The daemon is a persistent background
   process; leaving it running keeps consuming the worker pane indefinitely.

## Guardrails

- **Scope**: evolve only this repository, in small, verifiable, revertible
  steps; run the repo's existing typechecks/tests after each change. Never
  rewrite shared files outside the work unit under evolution.
- **Shared evolve log**: after each iteration, record goal / evidence /
  changes / validation / risks in the agent-level log
  `xdg_config/pi/agent/evolve/EVOLVE_LOG.md` (one `Iteration N` heading per round).
  This replaces any idea of writing the evolution log back into the evolved
  object's own directory.
- **Stop-file protocol**: the daemon only exits when its stop signal is created
  (`auto_evolve_stop`) or its safety attempt limit is reached. Touching the
  stop file is the graceful path — prefer it over killing the process.
- **One daemon per pane**: starting a second daemon for the same pane is
  refused automatically (returns `already-running`). Do not bypass that guard.
- **Shutdown**: if the worker pane disappears or the session changes, stop the
  daemon explicitly with `auto_evolve_stop`.
- **Unattended by design**: the daemon is unattended and self-driving; the parent
  model owns final integration and verification. Treat daemon output as useful
  evidence, not as proof — inspect diffs and run integrated validation.