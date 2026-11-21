# Pi extensions tracked in this repository

| Extension                          | Purpose                                                                    |
|------------------------------------|----------------------------------------------------------------------------|
| [auth](auth/README.md)             | Imports Codex OAuth credentials when a Pi session starts.                  |
| [status](status/README.md)         | Shows activity, model, token usage, cost, and context usage in the footer. |
| [subagent](subagent/README.md)     | Delegates a bounded task to a fresh Pi session and returns its handoff.    |
| [sessions](sessions/README.md)     | Finds saved Pi sessions by directory and title.                            |
| [mpl-render](mpl-render/README.md) | Renders charts as PNGs from codemode.                                      |

[Pi extension API documentation](https://pi.dev/docs/latest/extensions)

## Installation and tests

Each extension directory is a separate npm package. With Node.js 24 or newer,
run the following commands from the extension directory:

```sh
npm ci
npm test
```

`npm test` typechecks the package and runs its Vitest tests. The packages pin
Pi 1.3.0 for development. At runtime, Pi supplies the `pi-ai`, `pi-coding-agent`,
and `pi-tui` peer dependencies used by each extension.
