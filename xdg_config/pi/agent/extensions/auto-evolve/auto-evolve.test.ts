import { chmodSync, existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawn, spawnSync } from "node:child_process";
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
  target?: string;
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
      AUTO_EVOLVE_SNAPSHOT_DIR: join(root, "snapshots"),
      TMUX_TEST_CAPTURE: options.capture ?? "Pi is idle",
      TMUX_TEST_COMMAND: options.command ?? "node",
      TMUX_TEST_CWD: options.cwd ?? root,
      TMUX_TEST_SEND_LOG: sendLogPath,
      TMUX_TEST_STOP_ON_CAPTURE: String(options.stopOnCapture ?? false),
      AUTO_EVOLVE_TARGET: options.target ?? "",
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

/**
 * Launch a COPY of auto-evolve.sh placed in a temp "workspace" dir, driving a
 * fake tmux, and rewrite that workspace copy while the daemon runs. This
 * reproduces the original crash mode (bash streaming the workspace file while
 * self-evolution rewrites it mid-run) without touching the real script or
 * running a real daemon for a long time.
 */
function launchWorkspaceCopy(options: { attempts: number; intervalSec: number }) {
  const root = temporaryDirectory();
  const workspace = join(root, "workspace");
  mkdirSync(workspace, { recursive: true });
  const workspaceScript = join(workspace, "auto-evolve.sh");
  writeFileSync(workspaceScript, readFileSync(scriptPath, "utf8"));

  const bin = join(root, "bin");
  mkdirSync(bin);
  const tmuxPath = join(bin, "tmux");
  writeFileSync(tmuxPath, `#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  display-message) printf '%s\\n' "123\\t$TMUX_TEST_COMMAND\\t$TMUX_TEST_CWD" ;;
  capture-pane) printf '%s\\n' "$TMUX_TEST_CAPTURE" ;;
  send-keys) printf '%s\\n' "$*" >> "$TMUX_TEST_SEND_LOG" ;;
  *) exit 9 ;;
esac
`);
  chmodSync(tmuxPath, 0o755);

  const logPath = join(root, "auto-evolve.log");
  const sendLogPath = join(root, "send.log");
  const child = spawn("bash", [workspaceScript, "%7"], {
    env: {
      ...process.env,
      PANE: "",
      PATH: `${bin}:${process.env.PATH ?? ""}`,
      AUTO_EVOLVE_LOG: logPath,
      INTERVAL_SEC: String(options.intervalSec),
      RELOAD_DELAY_SEC: "0",
      SAFETY_MAX_ATTEMPTS: String(options.attempts),
      REPO_DIR: root,
      AUTO_EVOLVE_STOP_FILE: join(root, "stop"),
      AUTO_EVOLVE_SNAPSHOT_DIR: join(root, "snapshots"),
      TMUX_TEST_CAPTURE: "Pi is idle",
      TMUX_TEST_COMMAND: "node",
      TMUX_TEST_CWD: workspace,
      TMUX_TEST_SEND_LOG: sendLogPath,
      AUTO_EVOLVE_TARGET: "auto-evolve",
    },
  });
  let stderr = "";
  child.stderr?.on("data", (chunk) => (stderr += String(chunk)));
  const wait = (timeoutMs = 20_000) =>
    new Promise<{ code: number | null; stderr: string }>((resolve, reject) => {
      const timer = setTimeout(() => {
        child.kill("SIGKILL");
        reject(new Error("workspace daemon did not exit in time"));
      }, timeoutMs);
      child.on("close", (code) => {
        clearTimeout(timer);
        resolve({ code, stderr });
      });
    });
  return { root, workspaceScript, logPath, wait };
}

/** Half-written bash that previously crashed the streamed script mid-read. */
const BROKEN_SCRIPT = '#!/usr/bin/env bash\necho "half-written\nthen);\n';

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

  test("uses the configured evolution target in the continue prompt", () => {
    const result = runScript({ attempts: 1, target: "auto-evolve" });

    expect(result.status).toBe(0);
    expect(result.sendLog).toContain("请评估演化目标 auto-evolve 是否还有高价值、可验证的改进");
    expect(result.sendLog).not.toContain("请评估演化目标 subagent 是否还有高价值");
  });

  test("no longer defaults to subagent; falls back to the main-agent-decided target prompt", () => {
    const result = runScript({ attempts: 1 });

    expect(result.status).toBe(0);
    // No hardcoded target and no subagent demo anywhere.
    expect(result.sendLog).not.toContain("subagent");
    expect(result.sendLog).not.toContain("background scout 演示 widget");
    // With no target the daemon defers to the main agent's in-session decision.
    expect(result.sendLog).toContain("请继续推进该目标");
  });

  test("never triggers a background-scout widget demo", () => {
    const result = runScript({ attempts: 3 });

    expect(result.status).toBe(0);
    expect(result.sendLog).not.toContain("background scout 演示 widget");
  });
});

describe("self-snapshot resilience (daemon rewritten while running)", () => {
  test("survives the workspace script being rewritten mid-run across rounds", async () => {
    const run = launchWorkspaceCopy({ attempts: 2, intervalSec: 1 });

    // The daemon snapshots itself in the first few ms, so by 600ms it runs
    // from the stable copy; rewriting the workspace file then used to crash
    // the streamed original with "syntax error near unexpected token".
    await new Promise((resolve) => setTimeout(resolve, 600));
    writeFileSync(run.workspaceScript, BROKEN_SCRIPT);

    const outcome = await run.wait();
    const log = existsSync(run.logPath) ? readFileSync(run.logPath, "utf8") : "";

    expect(outcome.stderr).not.toContain("syntax error");
    expect(outcome.code).toBe(0);
    expect(log.match(/=== attempt \d+:/g)).toHaveLength(2);
    expect(log).toContain("safety limit reached; attempts=2");
    // the daemon executes from a stable snapshot, not the corrupted workspace
    expect(log).not.toContain("half-written");
  });

  test("survives the workspace script being rewritten right after launch", async () => {
    const run = launchWorkspaceCopy({ attempts: 1, intervalSec: 2 });

    // Concurrent rewrite while the single round is still sleeping in its first
    // (and only) lifecycle: the snapshot copy is already taken, so a freshly
    // corrupted workspace file must not affect the running process.
    await new Promise((resolve) => setTimeout(resolve, 250));
    writeFileSync(run.workspaceScript, BROKEN_SCRIPT);

    const outcome = await run.wait();
    const log = existsSync(run.logPath) ? readFileSync(run.logPath, "utf8") : "";

    expect(outcome.stderr).not.toContain("syntax error");
    expect(outcome.code).toBe(0);
    expect(log.match(/=== attempt \d+:/g)).toHaveLength(1);
    expect(log).toContain("safety limit reached; attempts=1");
    expect(log).not.toContain("half-written");
  });
});
