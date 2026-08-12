import { afterEach, describe, expect, test } from "vitest";
import { chmodSync, existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { createRpcSubagentController, createRpcSubagentExecutor } from "./rpc-executor.ts";
import type { SubagentExecutionProfile, SubagentRunOptions, SubagentWorkOrder } from "./protocol.ts";

const temporaryDirectories: string[] = [];
afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) rmSync(directory, { recursive: true, force: true });
  delete process.env.SUBAGENT_RPC_TEST_SECRET;
});

function temporaryScript(source: string): string {
  const directory = mkdtempSync(join(tmpdir(), "pi-subagent-rpc-"));
  temporaryDirectories.push(directory);
  const script = join(directory, "fake-pi.mjs");
  writeFileSync(script, source);
  chmodSync(script, 0o755);
  return script;
}

function workOrder(goal: string): SubagentWorkOrder {
  return {
    goal,
    scope: [process.cwd()],
    constraints: [],
    knownDecisions: [],
    evidence: [],
    validation: [],
    returnFormat: "Return findings.",
    projectGuidance: [],
  };
}

function profile(): SubagentExecutionProfile {
  return { name: "scout", systemPrompt: "Inspect files.", tools: ["read"] };
}

function options(script: string, sessionRoot: string, overrides: Partial<SubagentRunOptions> = {}): SubagentRunOptions & {
  command: string;
  commandArgsPrefix: string[];
  sessionRoot: string;
} {
  return {
    cwd: process.cwd(),
    agent: profile(),
    workOrder: workOrder("Inspect the fixture"),
    runId: "run-rpc",
    operationId: "operation-rpc",
    parentSessionId: "parent-rpc",
    deadlineMs: 5_000,
    ...overrides,
    command: process.execPath,
    commandArgsPrefix: [script],
    sessionRoot,
  };
}

describe("one-shot RPC executor", () => {
  test("reuses one controller sequentially and rejects invalid submit timing", async () => {
    const sessionRoot = mkdtempSync(join(tmpdir(), "pi-subagent-rpc-root-"));
    temporaryDirectories.push(sessionRoot);
    const exitMarker = join(sessionRoot, "exited");
    const script = temporaryScript(`
import { writeFileSync } from "node:fs";
let input = "";
const sessionFile = process.argv[process.argv.indexOf("--session-dir") + 1] + "/session.jsonl";
let getStateCount = 0;
function emit(value) { process.stdout.write(JSON.stringify(value) + "\\n"); }
process.stdin.on("data", (chunk) => {
  input += chunk;
  let newline;
  while ((newline = input.indexOf("\\n")) !== -1) {
    const command = JSON.parse(input.slice(0, newline));
    input = input.slice(newline + 1);
    if (command.type === "get_state") {
      getStateCount++;
      emit({ type: "response", id: command.id, command: "get_state", success: true, data: { sessionId: "reused-session", sessionFile } });
    }
    if (command.type === "prompt") {
      emit({ type: "response", id: command.id, command: "prompt", success: true });
      const goal = JSON.parse(command.message.split("\\n\\n")[1]).goal;
      setTimeout(() => {
        emit({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: goal }], stopReason: "stop" } });
        emit({ type: "agent_settled" });
      }, 20);
    }
  }
});
process.on("exit", () => writeFileSync(process.argv[2], String(getStateCount) + "|" + String(process.env.PI_SUBAGENT_OPERATION_ID)));
`);
    const firstOptions = options(script, sessionRoot, { operationId: "operation-1", workOrder: workOrder("first") });
    const controller = await createRpcSubagentController(firstOptions, {
      command: process.execPath,
      commandArgsPrefix: [script, exitMarker],
      sessionRoot,
    });
    const firstPending = controller.submit(firstOptions);
    await expect(controller.submit({ ...firstOptions, operationId: "concurrent" })).rejects.toThrow("active operation");
    const first = await firstPending;
    await expect(controller.submit({
      ...firstOptions,
      operationId: "mismatched",
      agent: { ...firstOptions.agent, tools: ["grep"] },
    })).rejects.toThrow("runtime identity");
    const second = await controller.submit({ ...firstOptions, operationId: "operation-2", workOrder: workOrder("second") });

    expect(first.summary).toBe("first");
    expect(second.summary).toBe("second");
    expect(second.operationId).toBe("operation-2");
    expect(first.processInstanceId).toBe(second.processInstanceId);
    expect(first.transcript).toEqual(second.transcript);
    first.transcript.sessionId = "mutated-by-caller";
    expect(second.transcript.sessionId).toBe("reused-session");
    const snapshot = controller.transcript as { sessionId?: string };
    snapshot.sessionId = "mutated-snapshot";
    expect(controller.transcript.sessionId).toBe("reused-session");
    firstOptions.agent.tools.push("grep");
    await expect(controller.submit({
      ...firstOptions,
      operationId: "mutated-profile",
    })).rejects.toThrow("runtime identity");
    await controller.close();
    expect(existsSync(exitMarker)).toBe(true);
    expect(readFileSync(exitMarker, "utf8")).toBe("1|undefined");
    const rejected = controller.start(firstOptions);
    await expect(rejected.accepted).rejects.toThrow("closed");
    await expect(rejected.result).rejects.toThrow("closed");
  });

  test("close cancels an unaccepted active operation and remains idempotent", async () => {
    const sessionRoot = mkdtempSync(join(tmpdir(), "pi-subagent-rpc-root-"));
    temporaryDirectories.push(sessionRoot);
    const script = temporaryScript(`
let input = "";
function emit(value) { process.stdout.write(JSON.stringify(value) + "\\n"); }
process.stdin.on("data", (chunk) => {
  input += chunk;
  let newline;
  while ((newline = input.indexOf("\\n")) !== -1) {
    const command = JSON.parse(input.slice(0, newline));
    input = input.slice(newline + 1);
    if (command.type === "get_state") emit({ type: "response", id: command.id, command: "get_state", success: true, data: { sessionId: "active", sessionFile: process.argv[process.argv.indexOf("--session-dir") + 1] + "/session.jsonl" } });
    if (command.type === "prompt") emit({ type: "response", id: command.id, command: "prompt", success: true });
  }
});
`);
    const runOptions = options(script, sessionRoot);
    const controller = await createRpcSubagentController(runOptions, {
      command: process.execPath,
      commandArgsPrefix: [script],
      sessionRoot,
    });
    const pending = controller.submit(runOptions);
    await new Promise((resolve) => setTimeout(resolve, 20));
    const firstClose = controller.close();
    expect(controller.close()).toBe(firstClose);
    await expect(pending).rejects.toThrow("closed during active operation");
    await expect(firstClose).resolves.toBeUndefined();
  });

  test("performs the state/prompt handshake and returns the session reference", async () => {
    const sessionRoot = mkdtempSync(join(tmpdir(), "pi-subagent-rpc-root-"));
    temporaryDirectories.push(sessionRoot);
    const script = temporaryScript(`
import { writeFileSync } from "node:fs";
let input = "";
const sessionDir = process.argv[process.argv.indexOf("--session-dir") + 1];
const sessionFile = sessionDir + "/session.jsonl";
function emit(value) { process.stdout.write(JSON.stringify(value) + "\\n"); }
process.stdin.on("data", (chunk) => {
  input += chunk;
  let newline;
  while ((newline = input.indexOf("\\n")) !== -1) {
    const command = JSON.parse(input.slice(0, newline));
    input = input.slice(newline + 1);
    if (command.type === "get_state") {
      writeFileSync(sessionFile, "fake transcript\\n");
      emit({ type: "response", id: command.id, command: "get_state", success: true, data: { sessionId: "session-rpc-1", sessionFile } });
    } else if (command.type === "prompt") {
      emit({ type: "response", id: command.id, command: "prompt", success: true });
      emit({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: JSON.stringify({ goal: command.message }) }], stopReason: "stop" } });
      emit({ type: "agent_settled" });
    }
  }
});
`);

    const result = await createRpcSubagentExecutor({ command: process.execPath, commandArgsPrefix: [script], sessionRoot })(options(script, sessionRoot));

    expect(result.status).toBe("completed");
    expect(result.processInstanceId).toMatch(/^[0-9a-f-]{36}$/);
    const summary = JSON.parse(result.summary);
    const delegatedWorkOrder = JSON.parse(summary.goal.split("\n\n", 2)[1]);
    expect(delegatedWorkOrder.goal).toBe("Inspect the fixture");
    expect(result.transcript.sessionId).toBe("session-rpc-1");
    expect(result.transcript.sessionPath).toBe(join(readdirSync(sessionRoot).map((name) => join(sessionRoot, name))[0], "session.jsonl"));
    expect(existsSync(result.transcript.sessionPath!)).toBe(true);
  });

  test("fails when the final assistant message is not a normal stop", async () => {
    const sessionRoot = mkdtempSync(join(tmpdir(), "pi-subagent-rpc-root-"));
    temporaryDirectories.push(sessionRoot);
    const script = temporaryScript(`
let input = "";
function emit(value) { process.stdout.write(JSON.stringify(value) + "\\n"); }
process.stdin.on("data", (chunk) => {
  input += chunk;
  let newline;
  while ((newline = input.indexOf("\\n")) !== -1) {
    const command = JSON.parse(input.slice(0, newline));
    input = input.slice(newline + 1);
    if (command.type === "get_state") emit({ type: "response", id: command.id, command: "get_state", success: true, data: { sessionId: "session-failed", sessionFile: process.argv[process.argv.indexOf("--session-dir") + 1] + "/session.jsonl" } });
    if (command.type === "prompt") {
      emit({ type: "response", id: command.id, command: "prompt", success: true });
      emit({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: "partial" }], stopReason: "length" } });
      emit({ type: "agent_settled" });
    }
  }
});
`);

    const result = await createRpcSubagentExecutor({ command: process.execPath, commandArgsPrefix: [script], sessionRoot })(options(script, sessionRoot));
    expect(result.status).toBe("failed");
    expect(result.summary).toBe("partial");
    expect(result.transcript.sessionId).toBe("session-failed");
    expect(result.transcript.sessionPath).toContain("session.jsonl");
  });

  test("preserves transcript evidence when submission fails after get_state", async () => {
    const sessionRoot = mkdtempSync(join(tmpdir(), "pi-subagent-rpc-root-"));
    temporaryDirectories.push(sessionRoot);
    const script = temporaryScript(`
let input = "";
function emit(value) { process.stdout.write(JSON.stringify(value) + "\\n"); }
process.stdin.on("data", (chunk) => {
  input += chunk;
  let newline;
  while ((newline = input.indexOf("\\n")) !== -1) {
    const command = JSON.parse(input.slice(0, newline));
    input = input.slice(newline + 1);
    const sessionFile = process.argv[process.argv.indexOf("--session-dir") + 1] + "/session.jsonl";
    if (command.type === "get_state") emit({ type: "response", id: command.id, command: "get_state", success: true, data: { sessionId: "session-evidence", sessionFile } });
    if (command.type === "prompt") emit({ type: "response", id: command.id, command: "prompt", success: false });
  }
});
`);

    const value = await createRpcSubagentExecutor({ command: process.execPath, commandArgsPrefix: [script], sessionRoot })(options(script, sessionRoot));
    expect(value.status).toBe("failed");
    expect(value.summary).toBe("RPC command failed: prompt");
    expect(value.transcript.sessionId).toBe("session-evidence");
    expect(value.transcript.sessionPath).toContain("session.jsonl");
  });

  test("rejects a transcript path outside the managed session directory", async () => {
    const sessionRoot = mkdtempSync(join(tmpdir(), "pi-subagent-rpc-root-"));
    temporaryDirectories.push(sessionRoot);
    const script = temporaryScript(`
let input = "";
function emit(value) { process.stdout.write(JSON.stringify(value) + "\\n"); }
process.stdin.on("data", (chunk) => {
  input += chunk;
  let newline;
  while ((newline = input.indexOf("\\n")) !== -1) {
    const command = JSON.parse(input.slice(0, newline));
    input = input.slice(newline + 1);
    if (command.type === "get_state") emit({ type: "response", id: command.id, command: "get_state", success: true, data: { sessionId: "escaped", sessionFile: "/tmp/escaped-session.jsonl" } });
  }
});
`);
    const result = await createRpcSubagentExecutor({
      command: process.execPath,
      commandArgsPrefix: [script],
      sessionRoot,
    })(options(script, sessionRoot));
    expect(result).toMatchObject({ status: "failed" });
    expect(result.summary).toContain("session file escaped");
  });

  test("fails closed on malformed RPC output", async () => {
    const sessionRoot = mkdtempSync(join(tmpdir(), "pi-subagent-rpc-root-"));
    temporaryDirectories.push(sessionRoot);
    const script = temporaryScript(`
process.stdin.once("data", () => process.stdout.write("{malformed\\n"));
`);
    const result = await createRpcSubagentExecutor({
      command: process.execPath,
      commandArgsPrefix: [script],
      sessionRoot,
    })(options(script, sessionRoot));
    expect(result).toMatchObject({ status: "failed" });
    expect(result.summary).toContain("Malformed JSONL record");
  });

  test("reduces RPC model and tool events to bounded redacted progress", async () => {
    const sessionRoot = mkdtempSync(join(tmpdir(), "pi-subagent-rpc-root-"));
    temporaryDirectories.push(sessionRoot);
    const script = temporaryScript(`
let input = "";
function emit(value) { process.stdout.write(JSON.stringify(value) + "\\n"); }
process.stdin.on("data", (chunk) => {
  input += chunk;
  let newline;
  while ((newline = input.indexOf("\\n")) !== -1) {
    const command = JSON.parse(input.slice(0, newline));
    input = input.slice(newline + 1);
    if (command.type === "get_state") emit({ type: "response", id: command.id, command: "get_state", success: true, data: { sessionId: "session-progress", sessionFile: process.argv[process.argv.indexOf("--session-dir") + 1] + "/session.jsonl" } });
    if (command.type === "prompt") {
      emit({ type: "response", id: command.id, command: "prompt", success: true });
      emit({ type: "agent_start" });
      emit({ type: "message_update", assistantMessageEvent: { type: "thinking_delta", delta: "private reasoning" } });
      emit({ type: "message_update", assistantMessageEvent: { type: "toolcall_start" } });
      emit({ type: "tool_execution_start", toolCallId: "tool-1", toolName: "read", args: { path: "token=rpc-secret-" + "x".repeat(300) } });
      emit({ type: "tool_execution_update", toolCallId: "tool-1", toolName: "read", partialResult: { content: [{ type: "text", text: "private tool output" }] } });
      emit({ type: "tool_execution_end", toolCallId: "tool-1", toolName: "read", isError: false, result: { content: [{ type: "text", text: "private tool output" }] } });
      emit({ type: "message_update", assistantMessageEvent: { type: "text_delta", delta: "Final answer" } });
      emit({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: "Final answer" }], stopReason: "stop" } });
      emit({ type: "agent_settled" });
    }
  }
});
`);
    process.env.SUBAGENT_RPC_TEST_SECRET = "rpc-secret";
    const progress: string[] = [];
    const execute = createRpcSubagentExecutor({
      command: process.execPath,
      commandArgsPrefix: [script],
      sessionRoot,
      authEnvAllowlist: ["SUBAGENT_RPC_TEST_SECRET"],
    });

    const result = await execute(options(script, sessionRoot, {
      onProgress: (summary) => progress.push(summary),
    }));

    expect(result.status).toBe("completed");
    expect(progress.slice(0, 3)).toEqual([
      "Child started; waiting for model…",
      "Thinking…",
      "Preparing tool call…",
    ]);
    expect(progress[3]).toMatch(/^read token=\[REDACTED\]-x+…$/);
    expect(progress[4]).toContain("completed; continuing…");
    expect(progress.slice(-2)).toEqual(["Writing response…", "Finalizing response…"]);
    expect(progress.join("\n")).not.toContain("private reasoning");
    expect(progress.join("\n")).not.toContain("private tool output");
    expect(progress.every((entry) => entry.length <= 161)).toBe(true);
  });

  test("aborts an accepted operation authoritatively and reuses the runtime", async () => {
    const sessionRoot = mkdtempSync(join(tmpdir(), "pi-subagent-rpc-root-"));
    temporaryDirectories.push(sessionRoot);
    const script = temporaryScript(`
let input = "";
let operation = 0;
function emit(value) { process.stdout.write(JSON.stringify(value) + "\\n"); }
process.stdin.on("data", (chunk) => {
  input += chunk;
  let newline;
  while ((newline = input.indexOf("\\n")) !== -1) {
    const command = JSON.parse(input.slice(0, newline));
    input = input.slice(newline + 1);
    if (command.type === "get_state") emit({ type: "response", id: command.id, command: "get_state", success: true, data: { sessionId: "session-cancelled", sessionFile: process.argv[process.argv.indexOf("--session-dir") + 1] + "/session.jsonl" } });
    if (command.type === "prompt") {
      operation++;
      emit({ type: "response", id: command.id, command: "prompt", success: true });
      if (operation === 2) setTimeout(() => {
        emit({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: "Still reusable" }], stopReason: "stop" } });
        emit({ type: "agent_settled" });
      }, 10);
    }
    if (command.type === "abort") {
      emit({ type: "agent_settled" });
      setTimeout(() => emit({ type: "response", id: command.id, command: "abort", success: true }), 20);
    }
  }
});
`);
    const firstOptions = options(script, sessionRoot, { operationId: "operation-interrupted" });
    const controller = await createRpcSubagentController(firstOptions, {
      command: process.execPath,
      commandArgsPrefix: [script],
      sessionRoot,
      terminationGraceMs: 25,
    });
    const first = controller.start(firstOptions);
    await first.accepted;
    expect(await controller.interrupt("stale-operation")).toBe(false);
    let resultSettled = false;
    void first.result.then(() => { resultSettled = true; });
    const interrupt = controller.interrupt(firstOptions.operationId);
    await new Promise((resolve) => setTimeout(resolve, 5));
    expect(resultSettled).toBe(false);
    expect(await interrupt).toBe(true);
    await expect(first.result).resolves.toMatchObject({ status: "interrupted" });

    const second = await controller.submit({ ...firstOptions, operationId: "operation-reused" });
    expect(second).toMatchObject({ status: "completed", summary: "Still reusable" });
    expect(second.processInstanceId).toBe(controller.processInstanceId);
    await controller.close();
  });

  test("steers only the expected accepted active operation", async () => {
    const sessionRoot = mkdtempSync(join(tmpdir(), "pi-subagent-rpc-root-"));
    temporaryDirectories.push(sessionRoot);
    const script = temporaryScript(`
let input = "";
function emit(value) { process.stdout.write(JSON.stringify(value) + "\\n"); }
process.stdin.on("data", (chunk) => {
  input += chunk;
  let newline;
  while ((newline = input.indexOf("\\n")) !== -1) {
    const command = JSON.parse(input.slice(0, newline));
    input = input.slice(newline + 1);
    const sessionFile = process.argv[process.argv.indexOf("--session-dir") + 1] + "/session.jsonl";
    if (command.type === "get_state") emit({ type: "response", id: command.id, command: "get_state", success: true, data: { sessionId: "session-steer", sessionFile } });
    if (command.type === "prompt") emit({ type: "response", id: command.id, command: "prompt", success: true });
    if (command.type === "steer") {
      emit({ type: "response", id: command.id, command: "steer", success: true });
      emit({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: command.message }], stopReason: "stop" } });
      emit({ type: "agent_settled" });
    }
  }
});
`);
    const runOptions = options(script, sessionRoot, { operationId: "operation-steered" });
    const controller = await createRpcSubagentController(runOptions, {
      command: process.execPath,
      commandArgsPrefix: [script],
      sessionRoot,
    });
    const operation = controller.start(runOptions);
    expect(await controller.steer(runOptions.operationId, "too early")).toBe(false);
    await operation.accepted;
    expect(await controller.steer("stale-operation", "wrong turn")).toBe(false);
    expect(await controller.steer(runOptions.operationId, "Focus on tests")).toBe(true);
    await expect(operation.result).resolves.toMatchObject({ status: "completed", summary: "Focus on tests" });
    expect(await controller.steer(runOptions.operationId, "too late")).toBe(false);
    await controller.close();
  });

  test("deadline aborts the operation without killing the reusable runtime", async () => {
    const sessionRoot = mkdtempSync(join(tmpdir(), "pi-subagent-rpc-root-"));
    temporaryDirectories.push(sessionRoot);
    const script = temporaryScript(`
let input = "";
let operation = 0;
function emit(value) { process.stdout.write(JSON.stringify(value) + "\\n"); }
process.stdin.on("data", (chunk) => {
  input += chunk;
  let newline;
  while ((newline = input.indexOf("\\n")) !== -1) {
    const command = JSON.parse(input.slice(0, newline));
    input = input.slice(newline + 1);
    const sessionFile = process.argv[process.argv.indexOf("--session-dir") + 1] + "/session.jsonl";
    if (command.type === "get_state") emit({ type: "response", id: command.id, command: "get_state", success: true, data: { sessionId: "session-deadline", sessionFile } });
    if (command.type === "prompt") {
      operation++;
      emit({ type: "response", id: command.id, command: "prompt", success: true });
      if (operation === 2) setTimeout(() => {
        emit({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: "After deadline" }], stopReason: "stop" } });
        emit({ type: "agent_settled" });
      }, 10);
    }
    if (command.type === "abort") {
      emit({ type: "response", id: command.id, command: "abort", success: true });
      emit({ type: "agent_settled" });
    }
  }
});
`);
    const firstOptions = options(script, sessionRoot, { operationId: "operation-deadline", deadlineMs: 20 });
    const controller = await createRpcSubagentController(firstOptions, {
      command: process.execPath,
      commandArgsPrefix: [script],
      sessionRoot,
    });
    await expect(controller.submit(firstOptions)).resolves.toMatchObject({
      status: "interrupted",
      summary: "Subagent execution deadline exceeded (20 ms)",
    });
    await expect(controller.submit({
      ...firstOptions,
      operationId: "operation-after-deadline",
      deadlineMs: 1_000,
    })).resolves.toMatchObject({ status: "completed", summary: "After deadline" });
    await controller.close();
  });

  test("abort watchdog fails a nonresponsive child instead of hanging", async () => {
    const sessionRoot = mkdtempSync(join(tmpdir(), "pi-subagent-rpc-root-"));
    temporaryDirectories.push(sessionRoot);
    const script = temporaryScript(`
let input = "";
function emit(value) { process.stdout.write(JSON.stringify(value) + "\\n"); }
process.stdin.on("data", (chunk) => {
  input += chunk;
  let newline;
  while ((newline = input.indexOf("\\n")) !== -1) {
    const command = JSON.parse(input.slice(0, newline));
    input = input.slice(newline + 1);
    const sessionFile = process.argv[process.argv.indexOf("--session-dir") + 1] + "/session.jsonl";
    if (command.type === "get_state") emit({ type: "response", id: command.id, command: "get_state", success: true, data: { sessionId: "session-watchdog", sessionFile } });
    if (command.type === "prompt") emit({ type: "response", id: command.id, command: "prompt", success: true });
    // Deliberately ignore abort and never emit agent_settled.
  }
});
`);
    const runOptions = options(script, sessionRoot);
    const controller = await createRpcSubagentController(runOptions, {
      command: process.execPath,
      commandArgsPrefix: [script],
      sessionRoot,
      terminationGraceMs: 25,
    });
    const operation = controller.start(runOptions);
    await operation.accepted;
    await expect(controller.interrupt(runOptions.operationId)).rejects.toThrow(
      "RPC abort did not reach authoritative settlement",
    );
    await expect(operation.result).rejects.toThrow("RPC abort did not reach authoritative settlement");
    await expect(controller.close()).rejects.toThrow("RPC abort did not reach authoritative settlement");
  });

  test.runIf(process.platform !== "win32")("cleans up descendants after a normal leader exit", async () => {
    const sessionRoot = mkdtempSync(join(tmpdir(), "pi-subagent-rpc-root-"));
    temporaryDirectories.push(sessionRoot);
    const descendantPidFile = join(sessionRoot, "descendant.pid");
    const script = temporaryScript(`
import { spawn } from "node:child_process";
import { writeFileSync } from "node:fs";
let input = "";
function emit(value) { process.stdout.write(JSON.stringify(value) + "\\n"); }
const descendant = spawn(process.execPath, ["-e", "setInterval(() => {}, 1000)"], { stdio: "ignore" });
writeFileSync(process.argv[2], String(descendant.pid));
descendant.unref();
process.stdin.on("data", (chunk) => {
  input += chunk;
  let newline;
  while ((newline = input.indexOf("\\n")) !== -1) {
    const command = JSON.parse(input.slice(0, newline));
    input = input.slice(newline + 1);
    if (command.type === "get_state") emit({ type: "response", id: command.id, command: "get_state", success: true, data: { sessionId: "session-cleanup", sessionFile: process.argv[process.argv.indexOf("--session-dir") + 1] + "/session.jsonl" } });
    if (command.type === "prompt") {
      emit({ type: "response", id: command.id, command: "prompt", success: true });
      emit({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: "Done" }], stopReason: "stop" } });
      emit({ type: "agent_settled" });
    }
  }
});
`);
    const execute = createRpcSubagentExecutor({
      command: process.execPath,
      commandArgsPrefix: [script, descendantPidFile],
      sessionRoot,
      terminationGraceMs: 25,
    });

    const result = await execute(options(script, sessionRoot));
    expect(result.status).toBe("completed");
    expect(existsSync(descendantPidFile)).toBe(true);
    const descendantPid = Number(await import("node:fs/promises").then(({ readFile }) => readFile(descendantPidFile, "utf8")));
    expect(() => process.kill(descendantPid, 0)).toThrow();
  });
});
