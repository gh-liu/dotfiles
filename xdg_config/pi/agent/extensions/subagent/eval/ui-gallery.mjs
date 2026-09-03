#!/usr/bin/env node

// Deterministic visual inventory for every current subagent renderer branch.
// This is a review tool, not a provider test: fixtures use the public
// run/followup/get/cancel/close contract and extension-produced details.

import {
  renderSubagentCall,
  renderSubagentCompletion,
  renderSubagentResult,
} from "../render/index.ts";
import { createLiveUi } from "../live-ui.ts";

const ansi = {
  reset: "\x1b[0m",
  bold: "\x1b[1m",
  colors: {
    accent: "\x1b[36m", dim: "\x1b[2m", error: "\x1b[31m", muted: "\x1b[90m",
    success: "\x1b[32m", syntaxFunction: "\x1b[35m", toolTitle: "\x1b[1;37m", warning: "\x1b[33m",
    thinkingOff: "\x1b[90m", thinkingMinimal: "\x1b[38;2;110;110;110m", thinkingLow: "\x1b[38;2;95;135;175m",
    thinkingMedium: "\x1b[38;2;129;162;190m", thinkingHigh: "\x1b[38;2;178;148;187m",
    thinkingXhigh: "\x1b[38;2;209;131;232m", thinkingMax: "\x1b[38;2;255;95;255m",
  },
  backgrounds: {
    toolErrorBg: "\x1b[48;5;52m", toolPendingBg: "\x1b[48;5;236m", toolSuccessBg: "\x1b[48;5;22m",
  },
};

const theme = {
  fg(color, text) { return `${ansi.colors[color] ?? ""}${text}${ansi.reset}`; },
  bg(color, text) { return `${ansi.backgrounds[color] ?? ""}${text}${ansi.reset}`; },
  bold(text) { return `${ansi.bold}${text}${ansi.reset}`; },
  getThinkingBorderColor(level) {
    const suffix = level === "off" ? "Off" : `${level[0]?.toUpperCase() ?? ""}${level.slice(1)}`;
    return (text) => this.fg(`thinking${suffix}`, text);
  },
};

const width = Number.parseInt(process.env.COLUMNS ?? "118", 10);
const category = process.argv[2] ?? "all";
const divider = () => "─".repeat(Math.min(width, 118));

function heading(title) {
  process.stdout.write(`\n${ansi.bold}${title}${ansi.reset}\n${divider()}\n`);
}

function row(label, component) {
  process.stdout.write(`${ansi.colors.muted}${label.padEnd(24)}${ansi.reset}`);
  const lines = component.render(width - 24).map((entry) => entry.trimEnd());
  process.stdout.write(`${lines[0] ?? ""}\n`);
  for (const entry of lines.slice(1)) process.stdout.write(`${" ".repeat(24)}${entry}\n`);
}

function renderCall(args, expanded = false, state = {}) {
  return renderSubagentCall(args, theme, { args, expanded, isError: false, state, invalidate() {} });
}

function renderResult(args, details, { expanded = false, partial = false, isError = false, text = "" } = {}) {
  return renderSubagentResult(
    { content: text ? [{ type: "text", text }] : [], details },
    { expanded, isPartial: partial },
    theme,
    { args, expanded, isError, state: {}, invalidate() {} },
  );
}

const task = "Map the subagent lifecycle and identify the safest change seam.";
const runArgs = {
  action: "run", agent: "scout", model: "stealth/ox-alpha", thinking: "minimal", task,
};

function calls() {
  heading("CALLS · reusable session API");
  row("run foreground", renderCall(runArgs, false, { runtimeIndex: 1 }));
  row("run background", renderCall({ ...runArgs, agent: "reviewer", background: true }, false, { runtimeIndex: 2 }));
  row("followup", renderCall({ action: "followup", ref: "#1", agent: "scout", task: "Compare the tests with the implementation." }, false, { model: "stealth/ox-alpha", thinking: "minimal", turn: 2 }));
  row("get recent", renderCall({ action: "get" }));
  row("get session", renderCall({ action: "get", ref: "#2", waitMs: 30_000 }, false, { ref: "#2" }));
  row("cancel", renderCall({ action: "cancel", ref: "#2" }, false, { ref: "#2" }));
  row("close", renderCall({ action: "close", ref: "#2" }, false, { ref: "#2" }));

  heading("CALL · expanded task");
  row("run expanded", renderCall(runArgs, true, { runtimeIndex: 1 }));
}

function progress() {
  heading("PROGRESS · tool-row receipt");
  row("active", renderResult(runArgs, {
    ref: "#1", status: "running", activity: "testing auth flow…",
    timeline: [{ kind: "thinking", text: "hidden" }, { kind: "tool", id: "read", summary: "read auth.ts", status: "completed" }],
    toolProgress: { earlierCount: 0, history: [], active: [{ id: "test", summary: "npm test auth" }] },
  }, { partial: true, text: "Thinking…" }));

  heading("PROGRESS · background activity center");
  let widgetFactory;
  const live = createLiveUi();
  live.attach({ setWidget(_id, content) { widgetFactory = content; } });
  const now = Date.now();
  live.track("job-1", { index: 1, agent: "scout", turn: 1, task, startedAt: now - 25_000, runId: "session-1" });
  live.progress("job-1", "Thinking", { kind: "thinking", status: "completed" });
  live.track("job-2", { index: 2, agent: "scout", turn: 2, task: "Compare Pi SDK lifecycle behavior with current subagent ownership and cite the relevant API contracts.", startedAt: now - 18_000, runId: "session-2" });
  live.progress("job-2", "web_search Pi SDK lifecycle…", { kind: "tool", status: "running" });
  live.track("job-3", { index: 3, agent: "reviewer", turn: 1, task: "Review the compatibility policy and identify any decision that changes the implementation.", startedAt: now - 11_000, runId: "session-3" });
  live.progress("job-3", "waiting for a decision", undefined, undefined, "Choose compatibility policy");
  if (typeof widgetFactory === "function") {
    const widget = widgetFactory({}, theme);
    for (const [index, entry] of widget.render(width).entries()) row(`live ${index + 1}`, { render: () => [entry] });
  }
  live.settle("job-2", "completed", 21_000);
  if (typeof widgetFactory === "function") {
    const widget = widgetFactory({}, theme);
    row("reporting", { render: () => [widget.render(width).find((entry) => entry.includes("#2")) ?? ""] });
  }
  live.reportFailed("job-2");
  if (typeof widgetFactory === "function") {
    const widget = widgetFactory({}, theme);
    row("delivery failed", { render: () => [widget.render(width).find((entry) => entry.includes("#2")) ?? ""] });
  }
  live.dispose();
}

function terminal() {
  heading("TERMINAL RESULTS · session outcomes");
  const cases = [
    ["run completed", runArgs, { ref: "#1", agent: "scout", turn: 1, status: "idle", turnStatus: "completed", summary: "Mapped the lifecycle and identified the ownership boundary.", elapsedMs: 54_000 }, {}],
    ["run interrupted", runArgs, { ref: "#1", agent: "scout", turn: 1, status: "idle", turnStatus: "interrupted", summary: "Stopped before synthesis.", elapsedMs: 14_000 }, {}],
    ["run crashed", runArgs, { ref: "#1", status: "crashed", error: "Provider authentication failed before generation." }, { isError: true }],
    ["get running", { action: "get", ref: "#2" }, { ref: "#2", turn: 2, status: "running", agent: "scout" }, {}],
    ["get timed out", { action: "get", ref: "#2", waitMs: 30_000 }, { ref: "#2", turn: 2, status: "running", agent: "scout", timedOut: true }, {}],
    ["get idle", { action: "get", ref: "#2" }, { ref: "#2", turn: 2, status: "idle", turnStatus: "completed", agent: "scout", summary: "Recovered background result." }, {}],
    ["get unknown", { action: "get", ref: "#99" }, { ref: "#99", status: "unknown", error: "Subagent session is unknown or expired." }, { isError: true }],
    ["cancel accepted", { action: "cancel", ref: "#2" }, { ref: "#2", status: "idle", turnStatus: "interrupted", cancelled: true }, {}],
    ["cancel idle", { action: "cancel", ref: "#2" }, { ref: "#2", status: "idle", cancelled: false, alreadyIdle: true }, {}],
    ["close", { action: "close", ref: "#2" }, { ref: "#2", status: "closed", agent: "scout", closed: true }, {}],
  ];
  for (const [label, args, details, options] of cases) row(label, renderResult(args, details, options));

  heading("TERMINAL RESULT · expanded handoff");
  row("expanded run", renderResult(runArgs, {
    ref: "#1", agent: "scout", turn: 1, status: "idle", turnStatus: "completed", elapsedMs: 54_000,
    summary: "Evidence\n- sdk-executor.ts owns the child session.\n- runtime.ts owns lifecycle transitions.\n\nValidation\n- Targeted tests passed.\n\nRisks\n- Restart recovery remains intentionally unsupported.",
  }, { expanded: true }));
}

function completions() {
  heading("BACKGROUND COMPLETION CARDS · single and batched");
  const base = {
    jobId: "job-2", operationId: "operation-2", turn: 2, ref: "#2", agent: "scout", model: "stealth/ox-alpha", thinking: "minimal", sessionOpen: true,
    task: "Map the runtime lifecycle and identify the safest change seam.",
    summary: "Evidence: runtime.ts owns transitions; sdk-executor.ts owns session events.",
    evidence: "runtime.ts owns transitions.", validation: "Targeted tests passed.", elapsedMs: 41_000,
  };
  for (const status of ["completed", "failed", "interrupted"]) {
    row(`${status} collapsed`, renderSubagentCompletion({ content: "", details: { ...base, status } }, { expanded: false, outputPad: 1 }, theme));
    row(`${status} expanded`, renderSubagentCompletion({ content: "", details: { ...base, status } }, { expanded: true, outputPad: 1 }, theme));
  }
  row("mixed batch", renderSubagentCompletion({ content: "", details: { batch: [
    { ...base, jobId: "job-1", operationId: "operation-1", ref: "#1", status: "completed", agent: "scout" },
    { ...base, jobId: "job-2", ref: "#2", status: "failed", agent: "scout", summary: "Provider request failed after acceptance." },
    { ...base, jobId: "job-3", operationId: "operation-3", ref: "#3", status: "interrupted", agent: "reviewer", summary: "Review was interrupted by the parent." },
  ] } }, { expanded: false, outputPad: 1 }, theme));
}

const sections = { calls, progress, terminal, completions };
if (category === "all") Object.values(sections).forEach((section) => section());
else if (sections[category]) sections[category]();
else {
  process.stderr.write(`Unknown category ${category}; use ${Object.keys(sections).join(", ")}, or all.\n`);
  process.exitCode = 2;
}
