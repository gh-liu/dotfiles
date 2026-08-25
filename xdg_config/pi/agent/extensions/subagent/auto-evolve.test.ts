import { chmodSync, existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

import { afterEach, describe, expect, test } from "vitest";

const temporaryDirectories: string[] = [];
const scriptPath = fileURLToPath(new URL("./auto-evolve.sh", import.meta.url));

function temporaryDirectory(): string {
  const directory = mkdtempSync(join(tmpdir(), "pi-auto-evolve-"));
  temporaryDirectories.push(directory);
  return directory;
}

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

function runScript(options: {
  args?: string[];
  capture?: string;
  command?: string;
  cwd?: string;
  attempts?: number;
  stopOnCapture?: boolean;
}) {
  const root = temporaryDirectory();
  const bin = join(root, "bin");
  mkdirSync(bin);
  const tmuxPath = join(bin, "tmux");
  writeFileSync(tmuxPath, `#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  display-message)
    printf '%s\\n' "123\\t$TMUX_TEST_COMMAND\\t$TMUX_TEST_CWD"
    ;;
  capture-pane)
    if [[ "$TMUX_TEST_STOP_ON_CAPTURE" == "true" ]]; then
      touch "$AUTO_EVOLVE_STOP_FILE"
    fi
    printf '%s\\n' "$TMUX_TEST_CAPTURE"
    ;;
  send-keys)
    printf '%s\\n' "$*" >> "$TMUX_TEST_SEND_LOG"
    ;;
  *) exit 9 ;;
esac
`);
  chmodSync(tmuxPath, 0o755);
  const logPath = join(root, "auto-evolve.log");
  const sendLogPath = join(root, "send.log");
  const result = spawnSync("bash", [scriptPath, ...(options.args ?? ["%7"])], {
    encoding: "utf8",
    env: {
      ...process.env,
      PANE: "",
      PATH: `${bin}:${process.env.PATH ?? ""}`,
      AUTO_EVOLVE_LOG: logPath,
      INTERVAL_SEC: "0",
      RELOAD_DELAY_SEC: "0",
      SAFETY_MAX_ATTEMPTS: String(options.attempts ?? 1),
      REPO_DIR: root,
      AUTO_EVOLVE_STOP_FILE: join(root, "stop"),
      TMUX_TEST_CAPTURE: options.capture ?? "Pi is idle",
      TMUX_TEST_COMMAND: options.command ?? "node",
      TMUX_TEST_CWD: options.cwd ?? root,
      TMUX_TEST_SEND_LOG: sendLogPath,
      TMUX_TEST_STOP_ON_CAPTURE: String(options.stopOnCapture ?? false),
    },
  });
  return {
    ...result,
    log: existsSync(logPath) ? readFileSync(logPath, "utf8") : "",
    sendLog: result.status === 0 && options.capture !== "RUNNING TOOLS"
      ? readFileSync(sendLogPath, "utf8")
      : "",
  };
}

describe("auto-evolve daemon safety", () => {
  test("requires an explicit pane", () => {
    const result = runScript({ args: [] });

    expect(result.status).toBe(2);
    expect(result.stderr).toContain("Usage:");
  });

  test.each([
    { command: "bash", label: "shell command" },
    { cwd: "/outside/repository", label: "cwd outside the repository" },
  ])("refuses a pane with $label", (invalid) => {
    const result = runScript(invalid);

    expect(result.status).not.toBe(0);
    expect(result.log).toContain("refusing input");
    expect(result.sendLog).toBe("");
  });

  test("counts busy skips toward the safety attempt limit", () => {
    const result = runScript({ capture: "RUNNING TOOLS", attempts: 3 });

    expect(result.status).toBe(0);
    expect(result.log.match(/=== attempt \d+:/g)).toHaveLength(3);
    expect(result.log).toContain("safety limit reached; attempts=3");
    expect(result.sendLog).toBe("");
  });

  test("stops when the model creates the run stop signal", () => {
    const result = runScript({ attempts: 10, stopOnCapture: true });

    expect(result.status).toBe(0);
    expect(result.log).toContain("model marked evolution complete");
    expect(result.log).not.toContain("=== attempt 3:");
  });

  test("sends reload only to a validated Pi pane", () => {
    const result = runScript({});

    expect(result.status).toBe(0);
    expect(result.sendLog).toContain("send-keys -t %7 -l /reload");
    expect(result.sendLog).toContain("send-keys -t %7 Enter");
  });
});
