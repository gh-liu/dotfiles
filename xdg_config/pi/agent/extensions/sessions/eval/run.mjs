#!/usr/bin/env node

import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { RpcClient } from "@earendil-works/pi-coding-agent";

const evalDirectory = dirname(fileURLToPath(import.meta.url));
const sessionsDirectory = resolve(evalDirectory, "..");
const extensionsRoot = resolve(evalDirectory, "../..");
const agentRoot = resolve(evalDirectory, "../../..");
const cliPath = realpathSync(join(
  extensionsRoot,
  "node_modules/@earendil-works/pi-coding-agent/dist/cli.js",
));
const extensionPath = join(sessionsDirectory, "index.ts");

const HISTORY_MARKER = "PI_SESSIONS_HISTORY_LIVE_7F3A";
const SEND_MARKER = "PI_SESSIONS_SEND_LIVE_4C2D";
const ASK_MARKER = "PI_SESSIONS_ASK_LIVE_9B6E";
const REPLY_MARKER = "PI_SESSIONS_REPLY_LIVE_OK";
const CANCEL_MARKER = "PI_SESSIONS_CANCEL_LIVE_2D8A";

const usage = `Usage: {node|bun} sessions/eval/run.mjs [options]

Runs real Pi processes against an isolated agent directory and verifies history
search plus active-session list/send/ask/pending/reply/cancel behavior.

Options:
  --model <provider/id>  Pi model (default: openai-codex/gpt-5.6-luna)
  --timeout <seconds>    Timeout per model turn (default: 120)
  --report <directory>   Artifact directory (default: a new /tmp directory)
  --keep                 Keep the isolated runtime and persisted test session
  --dry-run              Print the execution plan without provider calls
  --help                  Show this help
`;

function parseArguments(argv) {
  const options = {
    model: process.env.PI_SESSIONS_EVAL_MODEL ?? "openai-codex/gpt-5.6-luna",
    timeoutMs: 120_000,
    report: null,
    keep: false,
    dryRun: false,
    help: false,
  };
  const value = (flag, index) => {
    const result = argv[index + 1];
    if (!result || result.startsWith("--")) throw new Error(`${flag} requires a value`);
    return result;
  };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--model") {
      options.model = value(argument, index);
      index += 1;
    } else if (argument === "--timeout") {
      options.timeoutMs = Number.parseFloat(value(argument, index)) * 1000;
      index += 1;
    } else if (argument === "--report") {
      options.report = resolve(value(argument, index));
      index += 1;
    } else if (argument === "--keep") options.keep = true;
    else if (argument === "--dry-run") options.dryRun = true;
    else if (argument === "--help" || argument === "-h") options.help = true;
    else throw new Error(`Unknown option: ${argument}`);
  }
  if (!Number.isFinite(options.timeoutMs) || options.timeoutMs < 1_000) {
    throw new Error("--timeout must be at least 1 second");
  }
  return options;
}

function prepareReportDirectory(path) {
  if (!path) return mkdtempSync("/tmp/pi-sessions-eval-report-");
  mkdirSync(path, { recursive: true });
  if (existsSync(join(path, "report.json"))) {
    throw new Error(`Report already exists: ${join(path, "report.json")}`);
  }
  return path;
}

function createRuntimeDirectory() {
  if (process.platform === "win32") {
    throw new Error("The sessions local IPC transport is not supported on Windows");
  }
  // macOS limits Unix-domain socket paths to roughly 104 bytes. Keep this root
  // deliberately short instead of using its long per-user TMPDIR.
  return mkdtempSync("/tmp/pi-sess-");
}

function createIsolatedAgentDirectory(runtimeDirectory) {
  const directory = join(runtimeDirectory, "agent");
  mkdirSync(directory);
  for (const name of ["auth.json", "models.json", "models-store.json", "settings.json"]) {
    const source = join(agentRoot, name);
    if (existsSync(source)) copyFileSync(source, join(directory, name));
  }
  return directory;
}

function sync(args, env = process.env) {
  return spawnSync("node", [cliPath, ...args], {
    cwd: extensionsRoot,
    env,
    encoding: "utf8",
  });
}

function requireSuccess(result, label) {
  if (result.error || result.status !== 0) {
    throw new Error(`${label}: ${result.error?.message ?? result.stderr ?? result.stdout}`.trim());
  }
  return result.stdout.trim();
}

function preflight(options, agentDirectory) {
  const env = { ...process.env, PI_CODING_AGENT_DIR: agentDirectory };
  const version = requireSuccess(sync(["--version"], env), "Pi is not available");
  requireSuccess(
    sync(["auth", "check", "--model", options.model], env),
    `Pi authentication is not ready for ${options.model}`,
  );
  return version;
}

function clientArguments(name, systemPrompt, withExtension, persistent) {
  const args = [
    "--name", name,
    "--system-prompt", systemPrompt,
    "--approve",
    "--no-extensions",
    "--no-skills",
    "--no-prompt-templates",
    "--no-context-files",
    "--thinking", "minimal",
  ];
  if (!persistent) args.push("--no-session");
  if (withExtension) {
    args.push(
      "--extension", extensionPath,
      "--no-builtin-tools",
      "--tools", "sessions,session_message",
    );
  } else {
    args.push("--no-tools");
  }
  return args;
}

function createClient(records, options, agentDirectory, cwd, config) {
  const events = [];
  const client = new RpcClient({
    cliPath,
    cwd,
    env: { PI_CODING_AGENT_DIR: agentDirectory },
    model: options.model,
    args: clientArguments(config.name, config.systemPrompt, config.withExtension, config.persistent),
  });
  client.onEvent((event) => events.push(event));
  const record = { name: config.name, client, events, state: null, stderr: "", stopped: false };
  records.push(record);
  return record;
}

async function startClient(record) {
  await record.client.start();
  record.state = await record.client.getState();
}

async function stopClient(record) {
  if (record.stopped) return;
  record.stopped = true;
  await record.client.stop();
  record.stderr = record.client.getStderr();
}

async function runPrompt(record, prompt, timeoutMs) {
  const start = record.events.length;
  await record.client.promptAndWait(prompt, undefined, timeoutMs);
  return record.events.slice(start);
}

function waitForSettledAfter(record, start, predicate, timeoutMs) {
  const existing = record.events.slice(start);
  const matchIndex = existing.findIndex(predicate);
  if (matchIndex >= 0 && existing.slice(matchIndex + 1).some((event) => event.type === "agent_settled")) {
    return Promise.resolve();
  }
  return new Promise((resolveWait, rejectWait) => {
    let matched = matchIndex >= 0;
    let unsubscribe = () => {};
    const timer = setTimeout(() => {
      unsubscribe();
      rejectWait(new Error(`Timeout waiting for ${record.name} to settle after the expected event`));
    }, timeoutMs);
    unsubscribe = record.client.onEvent((event) => {
      if (!matched) {
        matched = predicate(event);
        return;
      }
      if (event.type !== "agent_settled") return;
      clearTimeout(timer);
      unsubscribe();
      resolveWait();
    });
  });
}

function toolCalls(events, toolName, action) {
  const starts = events.filter((event) =>
    event.type === "tool_execution_start"
    && event.toolName === toolName
    && (action === undefined || event.args?.action === action)
  );
  const ends = events.filter((event) => event.type === "tool_execution_end" && event.toolName === toolName);
  return starts.map((start) => ({
    start,
    end: ends.find((end) => end.toolCallId === start.toolCallId),
  }));
}

function resultDetails(call) {
  return call?.end?.result?.details ?? {};
}

function resultText(call) {
  return (call?.end?.result?.content ?? [])
    .filter((part) => part?.type === "text")
    .map((part) => part.text ?? "")
    .join("\n");
}

function check(checks, name, passed, detail) {
  checks.push({ name, passed: Boolean(passed), detail });
}

function validateHistory(checks, events, writerState, finalText) {
  const calls = toolCalls(events, "sessions", "search_history");
  const call = calls[0];
  const results = resultDetails(call).results ?? [];
  const match = results.find((result) => result.sessionId === writerState.sessionId);
  check(checks, "history tool invocation", calls.length === 1, `calls=${calls.length}`);
  check(
    checks,
    "history source match",
    match?.name === "history-source" && match?.snippet?.includes(HISTORY_MARKER),
    match ? `session=${match.sessionId} name=${match.name}` : "persisted source session was not returned",
  );
  check(
    checks,
    "history final answer",
    typeof finalText === "string" && finalText.includes("history-source"),
    finalText ?? "no final answer",
  );
}

function validateMessaging(checks, callerEvents, responderEvents, finalText) {
  const listCalls = toolCalls(callerEvents, "sessions", "list");
  const listed = resultDetails(listCalls[0]).results ?? [];
  check(checks, "active list invocation", listCalls.length === 1, `calls=${listCalls.length}`);
  check(
    checks,
    "active peer discovery",
    listed.some((session) => session.name === "caller" && session.self === true)
      && listed.some((session) => session.name === "responder" && session.self === false),
    `sessions=${listed.map((session) => `${session.name}:${session.self ? "self" : "peer"}`).join(",")}`,
  );

  const sendCalls = toolCalls(callerEvents, "session_message", "send");
  check(
    checks,
    "one-way send",
    sendCalls.length === 1 && resultDetails(sendCalls[0]).delivered === true,
    `calls=${sendCalls.length} result=${resultText(sendCalls[0])}`,
  );
  const receivedSend = responderEvents.some((event) =>
    (event.type === "message_start" || event.type === "message_end")
    && event.message?.role === "custom"
    && typeof event.message.content === "string"
    && event.message.content.includes(SEND_MARKER)
  );
  check(checks, "one-way delivery", receivedSend, receivedSend ? SEND_MARKER : "responder did not receive marker");

  const askCalls = toolCalls(callerEvents, "session_message", "ask");
  check(
    checks,
    "ask result",
    askCalls.length === 1 && resultText(askCalls[0]).trim() === REPLY_MARKER,
    `calls=${askCalls.length} result=${resultText(askCalls[0])}`,
  );

  const pendingCalls = toolCalls(responderEvents, "session_message", "pending");
  const pending = resultDetails(pendingCalls[0]).pending ?? [];
  check(
    checks,
    "pending inbound ask",
    pendingCalls.length === 1
      && pending.some((message) => message.from === "caller" && message.message.includes(ASK_MARKER)),
    `calls=${pendingCalls.length} pending=${pending.length}`,
  );

  const replyCalls = toolCalls(responderEvents, "session_message", "reply");
  check(
    checks,
    "reply delivery",
    replyCalls.length === 1
      && replyCalls[0].start.args?.message === REPLY_MARKER
      && resultDetails(replyCalls[0]).delivered === true,
    `calls=${replyCalls.length} result=${resultText(replyCalls[0])}`,
  );
  check(
    checks,
    "caller final answer",
    finalText?.trim() === REPLY_MARKER,
    finalText ?? "no final answer",
  );
}

function validateCancellation(checks, callerEvents, inboundEvents, pendingEvents, lateReplyEvents) {
  const askCalls = toolCalls(callerEvents, "session_message", "ask");
  check(
    checks,
    "cancelled ask result",
    askCalls.length === 1
      && askCalls[0].start.args?.message?.includes(CANCEL_MARKER)
      && resultDetails(askCalls[0]).code === "SESSION_MESSAGE_FAILED"
      && resultText(askCalls[0]).includes("Ask cancelled"),
    `calls=${askCalls.length} result=${resultText(askCalls[0])}`,
  );

  const inboundPendingCalls = toolCalls(inboundEvents, "session_message", "pending");
  const inboundPending = resultDetails(inboundPendingCalls[0]).pending ?? [];
  check(
    checks,
    "cancel target observed ask",
    inboundPendingCalls.length === 1
      && inboundPending.some((message) => message.message.includes(CANCEL_MARKER)),
    `calls=${inboundPendingCalls.length} pending=${inboundPending.length}`,
  );
  check(
    checks,
    "cancel target did not reply",
    toolCalls(inboundEvents, "session_message", "reply").length === 0,
    `replyCalls=${toolCalls(inboundEvents, "session_message", "reply").length}`,
  );

  const pendingCalls = toolCalls(pendingEvents, "session_message", "pending");
  const pending = resultDetails(pendingCalls[0]).pending ?? [];
  check(
    checks,
    "cancel clears pending inbound ask",
    pendingCalls.length === 1 && pending.length === 0,
    `calls=${pendingCalls.length} pending=${pending.length}`,
  );

  const lateReplyCalls = toolCalls(lateReplyEvents, "session_message", "reply");
  check(
    checks,
    "late reply rejected",
    lateReplyCalls.length === 1 && resultDetails(lateReplyCalls[0]).code === "UNKNOWN_MESSAGE",
    `calls=${lateReplyCalls.length} result=${resultText(lateReplyCalls[0])}`,
  );
}

function validateRuntimeErrors(checks, records, expectedFailures) {
  const failures = [];
  for (const record of records) {
    for (const event of record.events) {
      if (event.type === "extension_error") failures.push(`${record.name}: extension_error`);
      if (event.type === "tool_execution_end" && (event.isError || event.result?.details?.error)) {
        if (expectedFailures.has(event.toolCallId)) continue;
        failures.push(`${record.name}: ${event.toolName} ${event.result?.details?.code ?? "failed"}`);
      }
    }
  }
  check(checks, "no unexpected extension or tool errors", failures.length === 0, failures.join("; ") || "none");
}

function eventCost(records) {
  return records.reduce((sum, record) => sum + record.events.reduce((recordSum, event) => {
    if (event.type !== "message_end" || event.message?.role !== "assistant") return recordSum;
    return recordSum + (event.message.usage?.cost?.total ?? 0);
  }, 0), 0);
}

function configHash() {
  const hash = createHash("sha256");
  for (const path of [
    extensionPath,
    join(sessionsDirectory, "messaging/transport/index.ts"),
    join(sessionsDirectory, "messaging/transport/local-ipc.ts"),
    join(sessionsDirectory, "messaging/transport/local-ipc-broker.mjs"),
  ]) {
    hash.update(path.slice(sessionsDirectory.length));
    hash.update("\0");
    hash.update(readFileSync(path));
  }
  return hash.digest("hex");
}

function markdownReport(report) {
  const lines = [
    "# Pi sessions live evaluation",
    "",
    `- Timestamp: ${report.metadata.timestamp}`,
    `- Pi: ${report.metadata.piVersion}`,
    `- Model: ${report.metadata.model}`,
    `- Duration: ${(report.summary.durationMs / 1000).toFixed(1)}s`,
    `- Reported model cost: $${report.summary.cost.toFixed(4)}`,
    `- Status: **${report.summary.passed ? "PASS" : "FAIL"}**`,
    "",
    "| Check | Status | Detail |",
    "| --- | --- | --- |",
  ];
  for (const item of report.checks) {
    lines.push(`| ${item.name} | ${item.passed ? "PASS" : "FAIL"} | ${String(item.detail).replaceAll("|", "\\|")} |`);
  }
  lines.push("");
  return lines.join("\n");
}

function writeArtifacts(reportDirectory, records, report) {
  for (const record of records) {
    writeFileSync(
      join(reportDirectory, `${record.name}.jsonl`),
      record.events.map((event) => JSON.stringify(event)).join("\n") + (record.events.length ? "\n" : ""),
    );
    writeFileSync(join(reportDirectory, `${record.name}.stderr.log`), record.stderr);
  }
  writeFileSync(join(reportDirectory, "report.json"), `${JSON.stringify(report, null, 2)}\n`);
  writeFileSync(join(reportDirectory, "summary.md"), markdownReport(report));
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  if (options.help) {
    process.stdout.write(usage);
    return;
  }
  console.log(`Model: ${options.model}`);
  console.log("Real Pi processes: history-source -> caller + responder");
  console.log("Checks: search_history, list, send, ask, pending, reply, cancel");
  if (options.dryRun) return;

  const reportDirectory = prepareReportDirectory(options.report);
  const runtimeDirectory = createRuntimeDirectory();
  const agentDirectory = createIsolatedAgentDirectory(runtimeDirectory);
  const cwd = join(runtimeDirectory, "work");
  mkdirSync(cwd);
  const records = [];
  const checks = [];
  const startedAt = Date.now();
  let piVersion = "unknown";
  let historyFinal = null;
  let messagingFinal = null;
  let writerState = null;

  const stopAll = async () => {
    await Promise.allSettled(records.map((record) => stopClient(record)));
  };
  let interrupted = false;
  const interrupt = () => {
    if (interrupted) return;
    interrupted = true;
    void stopAll().finally(() => {
      if (!options.keep) rmSync(runtimeDirectory, { recursive: true, force: true });
      process.exit(130);
    });
  };
  process.once("SIGINT", interrupt);
  process.once("SIGTERM", interrupt);

  try {
    piVersion = preflight(options, agentDirectory);

    const writer = createClient(records, options, agentDirectory, cwd, {
      name: "history-source",
      persistent: true,
      withExtension: false,
      systemPrompt: "Reply with exactly HISTORY_WRITTEN. Do not add any other text.",
    });
    await startClient(writer);
    writerState = writer.state;
    console.log("[1/4] Creating a persisted real Pi session");
    await runPrompt(
      writer,
      `Store this unique searchable marker in this real session: ${HISTORY_MARKER}.`,
      options.timeoutMs,
    );
    await stopClient(writer);

    const caller = createClient(records, options, agentDirectory, cwd, {
      name: "caller",
      persistent: false,
      withExtension: true,
      systemPrompt: "Follow the requested tool sequence exactly. Use only sessions and session_message.",
    });
    await startClient(caller);
    console.log("[2/4] Searching persisted history through the sessions tool");
    const historyEvents = await runPrompt(
      caller,
      `Call sessions exactly once with action search_history and query ${HISTORY_MARKER}. Report only the matched session name.`,
      options.timeoutMs,
    );
    historyFinal = await caller.client.getLastAssistantText();
    validateHistory(checks, historyEvents, writerState, historyFinal);

    const responder = createClient(records, options, agentDirectory, cwd, {
      name: "responder",
      persistent: false,
      withExtension: true,
      systemPrompt: [
        "You are an IPC test responder.",
        `For a one-way session_message containing ${SEND_MARKER}, answer with exactly SEND_RECEIVED and call no tool.`,
        `For an incoming session_message containing ${CANCEL_MARKER}, call session_message with action pending exactly once, do not reply, and finish with exactly CANCEL_WAITING.`,
        "For any other incoming session_message that expects a reply, first call session_message with action pending exactly once.",
        `Then call session_message with action reply, the matching replyTo id, and message exactly ${REPLY_MARKER}.`,
        "Do not call any other tool.",
      ].join(" "),
    });
    await startClient(responder);
    console.log("[3/4] Exercising active list/send/ask/pending/reply across two Pi processes");
    const callerStart = caller.events.length;
    const responderStart = responder.events.length;
    const responderSettled = waitForSettledAfter(
      responder,
      responderStart,
      (event) => event.type === "tool_execution_start"
        && event.toolName === "session_message"
        && event.args?.action === "reply",
      options.timeoutMs,
    );
    const askTimeoutMs = Math.min(Math.max(Math.floor(options.timeoutMs * 0.8), 1_000), 600_000);
    await runPrompt(
      caller,
      [
        "Perform these steps sequentially and wait for each tool result:",
        "1. Call sessions with action list and confirm responder is active.",
        `2. Call session_message with action send, to responder, and message ${SEND_MARKER}.`,
        `3. Call session_message with action ask, to responder, message \"Return ${REPLY_MARKER}; request marker ${ASK_MARKER}\", and timeoutMs ${askTimeoutMs}.`,
        `Finish with exactly ${REPLY_MARKER}.`,
      ].join("\n"),
      options.timeoutMs,
    );
    messagingFinal = await caller.client.getLastAssistantText();
    await responderSettled;
    validateMessaging(
      checks,
      caller.events.slice(callerStart),
      responder.events.slice(responderStart),
      messagingFinal,
    );

    console.log("[4/4] Cancelling an active ask and checking receiver cleanup");
    const cancelCallerStart = caller.events.length;
    const cancelResponderStart = responder.events.length;
    const cancelResponderSettled = waitForSettledAfter(
      responder,
      cancelResponderStart,
      (event) => event.type === "tool_execution_start"
        && event.toolName === "session_message"
        && event.args?.action === "pending",
      options.timeoutMs,
    );
    const cancelRun = runPrompt(
      caller,
      `Call session_message exactly once with action ask, to responder, message "Do not reply; cancellation marker ${CANCEL_MARKER}", and timeoutMs ${askTimeoutMs}.`,
      options.timeoutMs,
    );
    await cancelResponderSettled;
    const inboundCancelEvents = responder.events.slice(cancelResponderStart);
    const cancelMessageId = resultDetails(toolCalls(inboundCancelEvents, "session_message", "pending")[0])
      .pending?.find((message) => message.message.includes(CANCEL_MARKER))?.messageId;
    if (!cancelMessageId) throw new Error("Responder did not expose the cancellable ask message id");
    await caller.client.abort();
    const cancelledAskEvents = await cancelRun;

    const pendingAfterCancelEvents = await runPrompt(
      responder,
      "Call session_message exactly once with action pending. Report only the number of pending asks.",
      options.timeoutMs,
    );
    const lateReplyEvents = await runPrompt(
      responder,
      `Call session_message exactly once with action reply, replyTo ${cancelMessageId}, and message LATE_REPLY. Report only the tool result.`,
      options.timeoutMs,
    );
    validateCancellation(
      checks,
      cancelledAskEvents,
      inboundCancelEvents,
      pendingAfterCancelEvents,
      lateReplyEvents,
    );
    const expectedFailures = new Set([
      ...toolCalls(cancelledAskEvents, "session_message", "ask"),
      ...toolCalls(lateReplyEvents, "session_message", "reply"),
    ].map((call) => call.start.toolCallId));
    validateRuntimeErrors(checks, records, expectedFailures);
  } catch (error) {
    check(
      checks,
      "evaluation completed",
      false,
      error instanceof Error ? error.message : String(error),
    );
  } finally {
    await stopAll();
    process.removeListener("SIGINT", interrupt);
    process.removeListener("SIGTERM", interrupt);
  }

  const report = {
    schemaVersion: 1,
    metadata: {
      timestamp: new Date().toISOString(),
      piVersion,
      model: options.model,
      timeoutMs: options.timeoutMs,
      configHash: configHash(),
      runtimeDirectory: options.keep ? runtimeDirectory : null,
    },
    markers: {
      history: HISTORY_MARKER,
      send: SEND_MARKER,
      ask: ASK_MARKER,
      reply: REPLY_MARKER,
      cancel: CANCEL_MARKER,
    },
    sessions: {
      historySourceId: writerState?.sessionId ?? null,
      historyFinal,
      messagingFinal,
    },
    checks,
    summary: {
      passed: checks.length > 0 && checks.every((item) => item.passed),
      passedChecks: checks.filter((item) => item.passed).length,
      failedChecks: checks.filter((item) => !item.passed).length,
      durationMs: Date.now() - startedAt,
      cost: eventCost(records),
    },
    artifacts: Object.fromEntries(records.map((record) => [record.name, {
      events: `${record.name}.jsonl`,
      stderr: `${record.name}.stderr.log`,
    }])),
  };
  writeArtifacts(reportDirectory, records, report);
  console.log(`\n${markdownReport(report)}`);
  console.log(`Artifacts: ${reportDirectory}`);
  if (options.keep) console.log(`Runtime: ${runtimeDirectory}`);
  else rmSync(runtimeDirectory, { recursive: true, force: true });
  if (!report.summary.passed) process.exitCode = 1;
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
