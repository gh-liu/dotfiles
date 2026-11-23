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
Pi 1.6.0 for development. At runtime, Pi supplies the `pi-ai`, `pi-coding-agent`,
`pi-tui`, and `typebox` peer dependencies used by each extension.

To bump all extension packages to the latest Pi release (or match the local
`pi` binary) and run every package's test suite:

```sh
./update-pi-deps.mjs           # latest version on npm
./update-pi-deps.mjs --from-pi # match local `pi --version`
./update-pi-deps.mjs --dry-run # preview changes only
```
