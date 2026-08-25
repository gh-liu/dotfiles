# evolve/ — self-evolution namespace

This directory is the **namespace of the self-evolution system**: the
evolution-artifact zone (log + contract) for every work unit driven by the pi
self-evolution loop. Moving the EVOLVE_LOG here is the naming rectification that
gives the self-evolution machinery a neutral identity of its own instead of
living under the subagent name.

## Directory positioning

- `xdg_config/pi/agent/evolve/` holds the **artifacts**: the shared evolution
  log (`EVOLVE_LOG.md`) and this contract (`README.md`).
- The **mechanism runtime code** (the auto-evolve extension: `index.ts`,
  `daemon.ts`, `probe.ts`, `auto-evolve.sh`) stays in
  `xdg_config/pi/agent/extensions/auto-evolve/` because pi only auto-discovers
  extensions from `extensions/*/index.ts`. Code cannot live here; artifacts do.

## Single-log contract

- **One shared log**: all driven objects — subagent extension, auto-evolve
  extension, other extensions, and configuration — append to the same
  `evolve/EVOLVE_LOG.md`. There are **no per-object logs**; do not write an
  evolution log back into the evolved object's own directory.
- **Ownership by iteration body**: which object an iteration belongs to is
  recorded in the body of each `## <date> Iteration N` entry, not by splitting
  files. Iteration 1–10 are the historical subagent iterations (they predate
  the promotion to a shared log and are preserved verbatim).

## Write rules

Every evolution round must be:

- **Small** — one bounded, focused change per iteration.
- **Verifiable** — run the narrowest relevant typechecks/tests and record the
  real output.
- **Revertible** — each iteration identifies its exact rollback path.

Each `Iteration N` entry records: **目标** (goal), **证据** (evidence),
**改动** (changes), **验证** (validation), **风险与回滚** (risks & rollback).

## Rollback

- To undo a whole iteration: revert the file changes it lists, then remove its
  `Iteration N` block from `EVOLVE_LOG.md`.
- To undo the namespace move itself: `git mv` the log back to the agent root,
  revert the path references in `extensions/auto-evolve/`, delete this
  `README.md`, and drop the corresponding log entry.