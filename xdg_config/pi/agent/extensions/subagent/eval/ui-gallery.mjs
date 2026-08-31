#!/usr/bin/env node

// Deterministic visual inventory for every current subagent renderer branch.
// This is a review tool, not a provider test: fixtures use the public
// run/get/cancel contract and the details shapes produced by the extension.

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
    success: "\x1b[32m", toolTitle: "\x1b[1;37m", warning: "\x1b[33m",
  },
  backgrounds: {
    toolErrorBg: "\x1b[48;5;52m", toolPendingBg: "\x1b[48;5;236m", toolSuccessBg: "\x1b[48;5;22m",
  },
};

const theme = {
  fg(color, text) { return `${ansi.colors[color] ?? ""}${text}${ansi.reset}`; },
  bg(color, text) { return `${ansi.backgrounds[color] ?? ""}${text}${ansi.reset}`; },
  bold(text) { return `${ansi.bold}${text}${ansi.reset}`; },
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

const objective = "Outcome: map the subagent lifecycle and identify the safest change seam.\nScope: spec.md, runtime.ts, sdk-executor.ts.\nConstraints: read-only; cite exact files and lines.\nValidation: compare implementation with tests.";
const runArgs = {
  action: "run", agent: "scout", model: "stealth/ox-alpha", thinking: "minimal", objective,
  cwd: `${process.env.HOME ?? "/home/user"}/dev/go-zero`, deadlineMs: 240_000,
};

function calls() {
  heading("CALLS · current run/get/cancel API");
  row("run foreground", renderCall(runArgs, false, { runtimeIndex: 1 }));
  row("run background", renderCall({ ...runArgs, agent: "researcher", background: true }, false, { runtimeIndex: 2 }));
  row("get recent", renderCall({ action: "get" }));
  row("get job", renderCall({ action: "get", jobId: "#2", waitMs: 30_000 }, false, { ref: "#2" }));
  row("cancel", renderCall({ action: "cancel", jobId: "#2" }, false, { ref: "#2" }));

  heading("CALL · expanded work order");
  row("run expanded", renderCall(runArgs, true, { runtimeIndex: 1 }));
}

const settledTimeline = [
  { kind: "tool", id: "a", summary: "read spec.md", status: "completed" },
  { kind: "thinking", text: "private reasoning is intentionally hidden" },
  { kind: "tool", id: "b", summary: "grep lifecycle runtime.ts", status: "completed" },
];

function progress() {
  heading("PROGRESS · partial result timeline");
  row("starting", renderResult(runArgs, { jobId: "job-1", ref: "#1", status: "starting" }, { partial: true, text: "Child started; waiting for model…" }));
  row("thinking", renderResult(runArgs, { jobId: "job-1", ref: "#1", status: "running", phase: { kind: "thinking", status: "running" } }, { partial: true, text: "Thinking…" }));
  row("tool running", renderResult(runArgs, {
    jobId: "job-1", ref: "#1", status: "running", timeline: settledTimeline,
    phase: { kind: "tool", status: "running" },
    toolProgress: { earlierCount: 0, history: [], active: [{ id: "c", summary: "bash npm test", status: "running" }] },
  }, { partial: true, text: "bash npm test…" }));
  row("tool failed", renderResult(runArgs, {
    jobId: "job-1", ref: "#1", status: "running", phase: { kind: "tool", status: "failed" },
    timeline: [...settledTimeline, { kind: "tool", id: "c", summary: "bash npm test", status: "failed" }],
  }, { partial: true, text: "bash npm test failed · reviewing…" }));
  row("writing", renderResult(runArgs, { jobId: "job-1", ref: "#1", status: "running", timeline: settledTimeline }, { partial: true, text: "Writing response…" }));

  heading("PROGRESS · live panel");
  let widgetFactory;
  const live = createLiveUi();
  live.attach({ setWidget(_id, content) { widgetFactory = content; } });
  const now = Date.now();
  live.track("job-1", { index: 1, agent: "scout", startedAt: now - 31_000, deadlineMs: 240_000, mode: "foreground" });
  live.progress("job-1", "grep lifecycle runtime.ts done · working…", { kind: "tool", status: "completed" });
  live.track("job-2", { index: 2, agent: "researcher", startedAt: now - 18_000, deadlineMs: 180_000, mode: "background" });
  live.progress("job-2", "web_search Pi SDK lifecycle…", { kind: "tool", status: "running" });
  if (typeof widgetFactory === "function") {
    const widget = widgetFactory({}, theme);
    for (const [index, entry] of widget.render(width).entries()) row(`live ${index + 1}`, { render: () => [entry] });
  }
  live.settle("job-2", "completed", 21_000);
  live.dispose();
}

function terminal() {
  heading("TERMINAL RESULTS · run/get/cancel outcomes");
  const cases = [
    ["run completed", runArgs, { jobId: "job-1", ref: "#1", status: "completed", summary: "Mapped the lifecycle and identified the ownership boundary.", elapsedMs: 54_000 }, {}],
    ["run interrupted", runArgs, { jobId: "job-1", ref: "#1", status: "interrupted", summary: "Stopped before synthesis.", elapsedMs: 14_000 }, {}],
    ["run failed", runArgs, { jobId: "job-1", ref: "#1", status: "failed", error: "Provider authentication failed before generation." }, { isError: true }],
    ["get running", { action: "get", jobId: "#2" }, { jobId: "job-2", ref: "#2", status: "running", agent: "researcher" }, {}],
    ["get timed out", { action: "get", jobId: "#2", waitMs: 30_000 }, { jobId: "job-2", ref: "#2", status: "running", agent: "researcher", timedOut: true }, {}],
    ["get completed", { action: "get", jobId: "#2" }, { jobId: "job-2", ref: "#2", status: "completed", agent: "researcher", handoff: { summary: "Recovered background result." } }, {}],
    ["cancel accepted", { action: "cancel", jobId: "#2" }, { jobId: "job-2", ref: "#2", status: "interrupted", cancelled: true }, {}],
    ["cancel terminal", { action: "cancel", jobId: "#2" }, { jobId: "job-2", ref: "#2", status: "completed", cancelled: false, alreadyTerminal: true }, {}],
  ];
  for (const [label, args, details, options] of cases) row(label, renderResult(args, details, options));

  heading("TERMINAL RESULT · expanded handoff");
  row("expanded run", renderResult(runArgs, {
    jobId: "job-1", ref: "#1", status: "completed", elapsedMs: 54_000,
    summary: "Evidence\n- sdk-executor.ts owns the child session.\n- runtime.ts owns lifecycle transitions.\n\nValidation\n- Targeted tests passed.\n\nRisks\n- Restart recovery remains intentionally unsupported.",
  }, { expanded: true }));
}

function completions() {
  heading("BACKGROUND COMPLETION CARDS · single and batched");
  const base = {
    jobId: "job-2", ref: "#2", agent: "scout", model: "stealth/ox-alpha", thinking: "minimal",
    task: "Map the runtime lifecycle and identify the safest change seam.",
    summary: "Evidence: runtime.ts owns transitions; sdk-executor.ts owns session events.",
    runtimeStatus: "idle", elapsedMs: 41_000,
  };
  for (const status of ["completed", "failed", "interrupted"]) {
    row(`${status} collapsed`, renderSubagentCompletion({ content: "", details: { ...base, status } }, { expanded: false, outputPad: 1 }, theme));
    row(`${status} expanded`, renderSubagentCompletion({ content: "", details: { ...base, status } }, { expanded: true, outputPad: 1 }, theme));
  }
  row("mixed batch", renderSubagentCompletion({ content: "", details: { batch: [
    { ...base, jobId: "job-1", ref: "#1", status: "completed", agent: "scout" },
    { ...base, jobId: "job-2", ref: "#2", status: "failed", agent: "researcher", summary: "Provider request failed after acceptance." },
    { ...base, jobId: "job-3", ref: "#3", status: "interrupted", agent: "reviewer", summary: "Review was interrupted by the parent." },
  ] } }, { expanded: false, outputPad: 1 }, theme));
}

const sections = { calls, progress, terminal, completions };
if (category === "all") Object.values(sections).forEach((section) => section());
else if (sections[category]) sections[category]();
else {
  process.stderr.write(`Unknown category ${category}; use ${Object.keys(sections).join(", ")}, or all.\n`);
  process.exitCode = 2;
}
