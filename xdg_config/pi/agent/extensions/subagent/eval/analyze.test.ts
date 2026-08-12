import { describe, expect, test } from "vitest";

import {
  aggregateResults,
  analyzeJsonl,
  compareSummaries,
  evaluateExpectation,
  parseJsonl,
} from "./analyze.mjs";

function line(event: unknown): string {
  return JSON.stringify(event);
}

describe("live subagent evaluation analysis", () => {
  test("parses valid events while preserving malformed and partial lines", () => {
    const parsed = parseJsonl(`${line({ type: "start" })}\nnot-json\n[1,2]\n{"type":`);

    expect(parsed.events).toEqual([{ type: "start" }]);
    expect(parsed.malformed).toEqual([
      { line: 2, text: "not-json" },
      { line: 3, text: "[1,2]" },
      { line: 4, text: '{"type":' },
    ]);
  });

  test("extracts parent tool calls, subagent roles and lifecycle actions", () => {
    const analysis = analyzeJsonl([
      line({ type: "tool_execution_start", toolName: "read", args: { path: "plan.md" } }),
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "start", agent: "scout", task: "Map" } }),
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "wait", id: "run" } }),
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "send", id: "run", mode: "follow_up" } }),
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "wait", id: "run" } }),
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "close", id: "run" } }),
    ].join("\n"));

    expect(analysis.parentToolCounts).toEqual({ read: 1, subagent: 5 });
    expect(analysis.subagentRoles).toEqual(["scout"]);
    expect(analysis.subagentActions).toEqual(["start", "wait", "send", "wait", "close"]);
    expect(evaluateExpectation(analysis, {
      requiredAgents: ["scout"],
      actionSequence: [
        { action: "start" },
        { action: "wait" },
        { action: "send", mode: "follow_up" },
        { action: "wait" },
        { action: "close" },
      ],
    })).toEqual({ passed: true, reasons: [] });
  });

  test("does not count child tool text embedded in a tool result as parent activity", () => {
    const analysis = analyzeJsonl([
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "run", agent: "researcher" } }),
      line({
        type: "tool_execution_end",
        toolName: "subagent",
        result: { content: [{ type: "text", text: 'child used {"toolName":"web_search"} twice' }] },
      }),
      line({
        type: "message_end",
        message: {
          role: "assistant",
          content: [{ type: "text", text: "Synthesis" }],
          usage: { input: 10, output: 5, totalTokens: 15, cost: { total: 0.02 } },
        },
      }),
    ].join("\n"));

    expect(analysis.parentToolCounts.web_search).toBeUndefined();
    expect(analysis.finalText).toBe("Synthesis");
    expect(analysis.usage).toMatchObject({ inputTokens: 10, outputTokens: 5, totalTokens: 15, cost: 0.02 });
    expect(evaluateExpectation(analysis, {
      requiredAgents: ["researcher"],
      parentToolCounts: { web_search: { max: 0 } },
    }).passed).toBe(true);
  });

  test("reports missing actions, schema failures, role order, and final evidence", () => {
    const analysis = analyzeJsonl([
      line({ type: "tool_execution_start", toolName: "subagent", args: { agent: "worker" } }),
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "run", agent: "reviewer" } }),
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "run", agent: "worker" } }),
      line({ type: "tool_execution_end", toolName: "subagent", isError: true, result: { content: [{ type: "text", text: "action is required by schema" }] } }),
      line({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: "No issues." }] } }),
    ].join("\n"));
    const result = evaluateExpectation(analysis, {
      agentOrder: ["worker", "reviewer"],
      finalAny: ["default.+TTL"],
    });

    expect(analysis.missingActionCalls).toHaveLength(1);
    expect(analysis.subagentErrors).toHaveLength(1);
    expect(analysis.schemaErrors).toHaveLength(1);
    expect(result.passed).toBe(false);
    expect(result.reasons).toHaveLength(2);
  });

  test("reports a failed subagent call even when a retry succeeds", () => {
    const analysis = analyzeJsonl([
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "run", agent: "scout" } }),
      line({ type: "tool_execution_end", toolName: "subagent", isError: true, result: { content: [{ type: "text", text: "Child cwd is outside the allowed root" }] } }),
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "run", agent: "scout" } }),
      line({ type: "tool_execution_end", toolName: "subagent", isError: false, result: { content: [{ type: "text", text: "complete" }] } }),
    ].join("\n"));

    expect(analysis.subagentErrors).toEqual([
      { name: "subagent", text: "Child cwd is outside the allowed root" },
    ]);
    expect(analysis.schemaErrors).toEqual([]);
  });

  test("recognizes independent evidence starts before either child settles", () => {
    const analysis = analyzeJsonl([
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "run", agent: "scout" } }),
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "run", agent: "researcher" } }),
      line({ type: "tool_execution_end", toolName: "subagent", isError: false }),
      line({ type: "tool_execution_end", toolName: "subagent", isError: false }),
    ].join("\n"));

    expect(analysis.parallelSubagentStarts).toEqual(["scout", "researcher"]);
    expect(evaluateExpectation(analysis, { parallelAgents: ["scout", "researcher"] })).toEqual({
      passed: true,
      reasons: [],
    });
  });

  test("rejects a decision that starts before evidence settles", () => {
    const analysis = analyzeJsonl([
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "run", agent: "scout" } }),
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "run", agent: "oracle" } }),
      line({ type: "tool_execution_end", toolName: "subagent", result: { content: [{ type: "text", text: "# Evidence\\nlocal" }] } }),
    ].join("\n"));
    expect(evaluateExpectation(analysis, {
      agentsBefore: { agents: ["scout"], before: "oracle" },
    }).passed).toBe(false);
  });

  test("checks required structured handoff sections", () => {
    const analysis = analyzeJsonl([
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "run", agent: "scout" } }),
      line({ type: "tool_execution_end", toolName: "subagent", result: { content: [{ type: "text", text: "# Evidence\nlocal\n# Validation\npassed\n# Blockers\nnone\n# Risks\nnone" }] } }),
    ].join("\n"));
    expect(evaluateExpectation(analysis, {
      handoffFields: ["evidence", "validation", "blockers", "risks"],
    })).toEqual({ passed: true, reasons: [] });
  });

  test("allows independent evidence agents in either order before a decision agent", () => {
    const analysis = analyzeJsonl([
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "start", agent: "researcher" } }),
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "start", agent: "scout" } }),
      line({ type: "tool_execution_end", toolName: "subagent", isError: false }),
      line({ type: "tool_execution_end", toolName: "subagent", isError: false }),
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "run", agent: "oracle" } }),
    ].join("\n"));

    expect(evaluateExpectation(analysis, {
      requiredAgents: ["scout", "researcher", "oracle"],
      agentsBefore: { agents: ["scout", "researcher"], before: "oracle" },
    })).toEqual({ passed: true, reasons: [] });
  });

  test("aggregates probability thresholds separately from deterministic failures", () => {
    const analysis = { usage: { cost: 0.01 }, subagentRoles: ["scout"] };
    const runs = [
      { scenarioId: "discovery", behavioral: { passed: true }, hardFailures: [], analysis, durationMs: 100 },
      { scenarioId: "discovery", behavioral: { passed: false }, hardFailures: [], analysis, durationMs: 200 },
      { scenarioId: "discovery", behavioral: { passed: false }, hardFailures: ["pi exited 1"], analysis, durationMs: 300 },
    ];
    const scenarios = [{ id: "discovery", targetRate: 2 / 3 }];

    expect(aggregateResults(runs, scenarios, false)[0]).toMatchObject({
      rate: 1 / 3,
      hardFailureCount: 1,
      status: "fail",
      agents: { scout: 3 },
    });
    const warningRuns = runs.map((run) => ({ ...run, hardFailures: [] }));
    expect(aggregateResults(warningRuns, scenarios, false)[0].status).toBe("warn");
    expect(aggregateResults(warningRuns, scenarios, true)[0].status).toBe("fail");
  });

  test("compares current routing rates with a baseline report", () => {
    const comparison = compareSummaries(
      [{ id: "research", rate: 1, hardFailureCount: 0, cost: 0.03 }],
      { summary: { scenarios: [{ id: "research", rate: 1 / 3, hardFailureCount: 1, cost: 0.02 }] } },
    );

    expect(comparison[0]).toMatchObject({
      rateBefore: 1 / 3,
      rateAfter: 1,
      hardFailuresBefore: 1,
      hardFailuresAfter: 0,
    });
    expect(comparison[0].rateDelta).toBeCloseTo(2 / 3);
  });
});
