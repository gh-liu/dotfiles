#!/usr/bin/env node

// Deterministic visual inventory for every subagent renderer branch. This is a
// review tool, not a provider test: it renders the production components with
// stable fixture details so rare races and failures are cheap to inspect.

import {
  renderSubagentCall,
  renderSubagentCompletion,
  renderSubagentResult,
} from "../render.ts";
import { createLiveUi } from "../live-ui.ts";

const ansi = {
  reset: "\x1b[0m",
  bold: "\x1b[1m",
  colors: {
    accent: "\x1b[36m",
    dim: "\x1b[2m",
    error: "\x1b[31m",
    muted: "\x1b[90m",
    success: "\x1b[32m",
    toolTitle: "\x1b[1;37m",
    warning: "\x1b[33m",
  },
  backgrounds: {
    toolErrorBg: "\x1b[48;5;52m",
    toolPendingBg: "\x1b[48;5;236m",
    toolSuccessBg: "\x1b[48;5;22m",
  },
};

const theme = {
  fg(color, text) { return `${ansi.colors[color] ?? ""}${text}${ansi.reset}`; },
  bg(color, text) { return `${ansi.backgrounds[color] ?? ""}${text}${ansi.reset}`; },
  bold(text) { return `${ansi.bold}${text}${ansi.reset}`; },
};

const width = Number.parseInt(process.env.COLUMNS ?? "118", 10);
const category = process.argv[2] ?? "all";
const line = (character = "─") => character.repeat(Math.min(width, 118));

function heading(title) {
  process.stdout.write(`\n${ansi.bold}${title}${ansi.reset}\n${line()}\n`);
}

function row(label, component) {
  process.stdout.write(`${ansi.colors.muted}${label.padEnd(24)}${ansi.reset}`);
  const lines = component.render(width - 24).map((entry) => entry.trimEnd());
  process.stdout.write(`${lines[0] ?? ""}\n`);
  for (const entry of lines.slice(1)) process.stdout.write(`${" ".repeat(24)}${entry}\n`);
}

function renderCall(args, expanded = false, state = {}) {
  return renderSubagentCall(args, theme, {
    args,
    expanded,
    isError: false,
    state,
    invalidate() {},
  });
}

function renderResult(args, details, { expanded = false, partial = false, isError = false, text = "" } = {}) {
  return renderSubagentResult(
    { content: text ? [{ type: "text", text }] : [], details },
    { expanded, isPartial: partial },
    theme,
    { args, expanded, isError, state: {}, invalidate() {} },
  );
}

const runArgs = {
  action: "run",
  agent: "scout",
  model: "stealth/ox-alpha",
  thinking: "minimal",
  task: "Outcome: map the subagent lifecycle and identify the safest change seam.\nScope: spec.md, runtime.ts, sdk-executor.ts.\nConstraints: read-only; cite exact files and lines.\nValidation: compare implementation with tests.",
  cwd: `${process.env.HOME ?? "/home/user"}/dev/go-zero`,
  deadlineMs: 240_000,
};

function calls() {
  heading("CALLS · collapsed");
  row("list", renderCall({ action: "list" }));
  row("run", renderCall(runArgs, false, { runtimeIndex: 1 }));
  row("start", renderCall({ ...runArgs, action: "start", agent: "researcher" }, false, { runtimeIndex: 2 }));
  row("status all", renderCall({ action: "status" }, true));
  row("status #2", renderCall({ action: "status", id: "#2" }, true));
  row("follow-up", renderCall({ action: "send", id: "#2", mode: "follow_up", message: "Compare the discovered behavior with spec acceptance and list any gaps.", deadlineMs: 90_000 }));
  row("steer", renderCall({ action: "send", id: "#2", mode: "steer", message: "Stop broad discovery; focus on sdk-executor.ts cleanup behavior.", expectedOperationId: "operation-2" }));
  row("wait all", renderCall({ action: "wait", timeoutMs: 30_000 }));
  row("wait #2", renderCall({ action: "wait", id: "#2", operationId: "operation-2", timeoutMs: 30_000 }));
  row("interrupt", renderCall({ action: "interrupt", id: "#2", expectedOperationId: "operation-2" }));
  row("close", renderCall({ action: "close", id: "#2" }, true));

  heading("CALLS · expanded work order");
  row("run expanded", renderCall(runArgs, true, { runtimeIndex: 1 }));
  row("follow-up expanded", renderCall({ action: "send", id: "#2", mode: "follow_up", message: "Outcome: verify the proposed fix.\nScope: only the changed files.\nConstraints: do not edit.\nValidation: run targeted tests.\nHandoff: findings, evidence, risks.", deadlineMs: 90_000 }, true));
}

function progress() {
  heading("PROGRESS · partial tool result + live panel");
  row("starting", renderResult(runArgs, { index: 1, status: "starting", startedAt: Date.now() - 2_000 }, { partial: true, text: "Child started; waiting for model…" }));
  row("thinking", renderResult(runArgs, { index: 1, status: "running", startedAt: Date.now() - 12_000 }, { partial: true, text: "Thinking…" }));
  row("tool running", renderResult(runArgs, { index: 1, status: "running", startedAt: Date.now() - 31_000 }, { partial: true, text: "grep runtime lifecycle…" }));
  row("tool completed", renderResult(runArgs, { index: 1, status: "running", startedAt: Date.now() - 38_000 }, { partial: true, text: "grep runtime lifecycle done · working…" }));
  row("tool failed", renderResult(runArgs, { index: 1, status: "running", startedAt: Date.now() - 43_000 }, { partial: true, text: "read missing.ts failed · reviewing…" }));
  row("writing", renderResult(runArgs, { index: 1, status: "running", startedAt: Date.now() - 51_000 }, { partial: true, text: "Writing response…" }));

  let widgetFactory;
  const live = createLiveUi();
  live.attach({ setWidget(_id, content) { if (content) widgetFactory = content; } });
  const now = Date.now();
  live.track("run-1", { index: 1, agent: "scout", startedAt: now - 31_000, deadlineMs: 240_000, mode: "foreground" });
  live.progress("run-1", "grep runtime lifecycle done · working…");
  live.track("run-2", { index: 2, agent: "researcher", startedAt: now - 18_000, deadlineMs: 180_000, mode: "background" });
  live.progress("run-2", "web_search Pi SDK session lifecycle…");
  if (widgetFactory) {
    const widget = widgetFactory({}, theme);
    for (const [index, entry] of widget.render(width).entries()) row(`live ${index + 1}`, { render: () => [entry] });
  }
  live.settle("run-2", "completed", 21_000);
  if (widgetFactory) {
    const widget = widgetFactory({}, theme);
    row("background idle", { render: () => [widget.render(width)[1] ?? ""] });
  }
  live.dispose();
}

function terminal() {
  heading("TERMINAL RESULTS · lifecycle and control outcomes");
  const cases = [
    ["run completed", runArgs, { index: 1, status: "completed", summary: "Mapped the lifecycle; the SDK controller owns acceptance and authoritative settlement.", elapsedMs: 54_000 }, {}],
    ["run interrupted", runArgs, { index: 1, status: "interrupted", summary: "Stopped before final synthesis.", controllerCancellation: true, elapsedMs: 14_000 }, {}],
    ["provider failed", runArgs, { index: 1, status: "failed", error: "Provider authentication failed before generation." }, { isError: true }],
    ["runtime running", { action: "status", id: "#2" }, { index: 2, status: "running", activeOperation: { task: "Compare implementation with spec" } }, {}],
    ["runtime idle", { action: "status", id: "#2" }, { index: 2, status: "idle" }, {}],
    ["runtime crashed", { action: "status", id: "#2" }, { index: 2, status: "crashed", error: "Session ended without authoritative settlement." }, {}],
    ["runtime cancelled", { action: "status", id: "#2" }, { index: 2, status: "cancelled" }, {}],
    ["runtime closed", { action: "status", id: "#2" }, { index: 2, status: "closed" }, { expanded: true }],
    ["start accepted", { ...runArgs, action: "start" }, { index: 2, status: "running" }, {}],
    ["wait timeout", { action: "wait", id: "#2", operationId: "op-2" }, { reason: "timeout", snapshot: { index: 2, status: "running" } }, {}],
    ["interrupt accepted", { action: "interrupt", id: "#2", expectedOperationId: "op-2" }, { accepted: true, status: "running" }, {}],
    ["interrupt conflict", { action: "interrupt", id: "#2", expectedOperationId: "old-op" }, { accepted: false, status: "idle" }, {}],
    ["steer accepted", { action: "send", id: "#2", mode: "steer", message: "Focus", expectedOperationId: "op-2" }, { accepted: true, status: "running" }, {}],
    ["steer rejected", { action: "send", id: "#2", mode: "steer", message: "Focus", expectedOperationId: "old-op" }, { accepted: false, status: "idle" }, {}],
    ["follow-up done", { action: "send", id: "#2", mode: "follow_up", message: "Check tests", deadlineMs: 90_000 }, { index: 2, status: "completed", summary: "The acceptance race and late interrupt are covered.", elapsedMs: 32_000 }, {}],
    ["close", { action: "close", id: "#2" }, { index: 2, status: "closed" }, { expanded: true }],
    ["list", { action: "list" }, {}, { text: "scout — local discovery\nresearcher — source-heavy web research\nreviewer — independent review\nworker — implementation" }],
  ];
  for (const [label, args, details, options] of cases) row(label, renderResult(args, details, options));

  heading("TERMINAL RESULT · expanded evidence");
  row("expanded run", renderResult(runArgs, {
    index: 1,
    status: "completed",
    task: runArgs.task,
    summary: "Evidence\n- sdk-executor.ts owns the child session.\n- runtime.ts owns lifecycle transitions.\n\nValidation\n- Targeted tests passed.\n\nRisks\n- Restart recovery remains intentionally unsupported.",
    elapsedMs: 54_000,
    transcript: { sessionPath: `${process.env.HOME ?? "/home/user"}/.pi/agent/subagent-sessions/run-1/session.jsonl` },
  }, { expanded: true }));
}

function completions() {
  heading("BACKGROUND COMPLETION CARDS · single and batched");
  const base = {
    index: 2,
    runId: "run-2",
    operationId: "operation-2",
    agent: "scout",
    model: "stealth/ox-alpha",
    thinking: "minimal",
    task: "Map the runtime lifecycle and identify the safest change seam.",
    summary: "Evidence: runtime.ts owns transitions; sdk-executor.ts owns session events.",
    runtimeStatus: "idle",
    elapsedMs: 41_000,
  };
  for (const status of ["completed", "failed", "interrupted"]) {
    row(`${status} collapsed`, renderSubagentCompletion({ content: "", details: { ...base, status } }, { expanded: false, outputPad: 1 }, theme));
    row(`${status} expanded`, renderSubagentCompletion({ content: "", details: { ...base, status } }, { expanded: true, outputPad: 1 }, theme));
  }
  row("batch", renderSubagentCompletion({ content: "", details: { batch: [
    { ...base, index: 1, status: "completed", agent: "scout" },
    { ...base, index: 2, status: "failed", agent: "researcher", summary: "Provider request failed after acceptance." },
    { ...base, index: 3, status: "interrupted", agent: "reviewer", summary: "Review was interrupted by the parent." },
  ] } }, { expanded: false, outputPad: 1 }, theme));
}

const sections = { calls, progress, terminal, completions };
if (category === "all") Object.values(sections).forEach((section) => section());
else if (sections[category]) sections[category]();
else {
  process.stderr.write(`Unknown category ${category}; use ${Object.keys(sections).join(", ")}, or all.\n`);
  process.exitCode = 2;
}
