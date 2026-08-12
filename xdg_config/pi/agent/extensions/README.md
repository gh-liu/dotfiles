# extensions

https://pi.dev/docs/latest/extensions

## Web search

`websearch` registers a local `web_search` tool backed by the Exa Search API. Export
`EXA_API_KEY` in the environment that starts Pi.

## Sessions

The `sessions` extension registers two tools:

- `sessions`: search local Pi session history with `search_history`, or list active
  Pi sessions connected through the local Unix-domain-socket transport with `list`.
- `session_message`: communicate with an active session using `send`, `ask`,
  `reply`, `pending`, or `cancel`.

History search remains available when local IPC is unavailable. Active-session
operations require the target session to have this extension loaded and connected.
The active-session transport uses a private Unix-domain socket under
`$PI_CODING_AGENT_DIR/runtime` on macOS and Linux; Windows is not supported.

`node sessions/eval/run.mjs` starts real isolated Pi processes and validates
history search plus active `list`, `send`, `ask`, `pending`, `reply`, and `cancel`
behavior.
It uses provider credentials and model quota, so it is intentionally separate
from `npm test`. See [sessions/eval/README.md](sessions/eval/README.md) for usage,
assertions, and artifacts.

## Subagent live evaluation

`node subagent/eval/run.mjs --quick` (or the equivalent `bun` command) runs real
Pi sessions against isolated fixtures to evaluate subagent routing and outcomes.
It uses provider credentials, network access, and model quota, so it is
intentionally separate from `npm test`. There is no package-script alias so the
runner is equally usable with Node.js or Bun. See
[subagent/eval/README.md](subagent/eval/README.md) for the scenario matrix, full
statistical run, report format, and baseline comparison workflow.
