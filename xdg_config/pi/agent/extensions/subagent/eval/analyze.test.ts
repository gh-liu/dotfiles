import { describe, expect, test } from "vitest";

import {
  aggregateResults,
  analyzeJsonl,
  compareSummaries,
  evaluateExpectation,
  evaluateExpectedSubagentErrors,
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
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "run", agent: "scout", task: "Map" } }),
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "followup", ref: "#1", task: "Compare tests" } }),
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "get", ref: "#1" } }),
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "close", ref: "#1" } }),
    ].join("\n"));

    expect(analysis.parentToolCounts).toEqual({ read: 1, subagent: 4 });
    expect(analysis.subagentRoles).toEqual(["scout"]);
    expect(analysis.subagentActions).toEqual(["run", "followup", "get", "close"]);
    expect(evaluateExpectation(analysis, {
      requiredAgents: ["scout"],
      actionSequence: [
        { action: "run" },
        { action: "followup" },
        { action: "get" },
        { action: "close" },
      ],
    })).toEqual({ passed: true, reasons: [] });
  });

  test("does not count child tool text embedded in a tool result as parent activity", () => {
    const analysis = analyzeJsonl([
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "run", agent: "scout" } }),
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
      requiredAgents: ["scout"],
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

  test("requires parent verification after a writing subagent settles", () => {
    const analysis = analyzeJsonl([
      line({ type: "tool_execution_start", toolCallId: "worker-call", toolName: "subagent", args: { action: "run", agent: "worker", task: "Implement plan.md" } }),
      line({ type: "tool_execution_start", toolCallId: "early-diff", toolName: "bash", args: { command: "git diff --check" } }),
      line({ type: "tool_execution_end", toolCallId: "worker-call", toolName: "subagent", isError: false }),
      line({ type: "tool_execution_start", toolCallId: "diff", toolName: "bash", args: { command: "git diff -- src/session.js test/session.test.js" } }),
      line({ type: "tool_execution_start", toolCallId: "tests", toolName: "bash", args: { command: "npm test" } }),
    ].join("\n"));

    expect(evaluateExpectation(analysis, {
      parentToolCallsAfter: [
        { agent: "worker", tool: "bash", argsMatch: "git\\s+diff" },
        { agent: "worker", tool: "bash", argsMatch: "npm\\s+test" },
      ],
    })).toEqual({ passed: true, reasons: [] });
    expect(evaluateExpectation(analysis, {
      parentToolCallsAfter: [
        { agent: "worker", tool: "bash", argsMatch: "git\\s+status" },
      ],
    })).toEqual({
      passed: false,
      reasons: ["parent did not call bash matching /git\\s+status/ after worker settled"],
    });
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

  test("consumes only an explicitly expected capacity error and leaves every other failure fatal", () => {
    const capacity = { name: "subagent", text: "Subagent capacity unavailable: maxConcurrentRuns is 3." };
    const provider = { name: "subagent", text: "Provider failed after acceptance" };
    const expected = [{
      pattern: "Subagent capacity unavailable: maxConcurrentRuns is 3\\.",
      count: 1,
    }];
    expect(evaluateExpectedSubagentErrors([capacity], expected)).toEqual({
      reasons: [],
      unexpected: [],
    });
    expect(evaluateExpectedSubagentErrors([capacity, provider], expected)).toEqual({
      reasons: [],
      unexpected: [provider],
    });
    expect(evaluateExpectedSubagentErrors([], expected)).toEqual({
      reasons: ["subagent errors matching /Subagent capacity unavailable: maxConcurrentRuns is 3\\./: 0 != 1"],
      unexpected: [],
    });
  });

  test("recognizes independent evidence starts before either child settles", () => {
    const analysis = analyzeJsonl([
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "run", agent: "scout" } }),
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "run", agent: "reviewer" } }),
      line({ type: "tool_execution_end", toolName: "subagent", isError: false }),
      line({ type: "tool_execution_end", toolName: "subagent", isError: false }),
    ].join("\n"));

    expect(analysis.parallelSubagentStarts).toEqual(["scout", "reviewer"]);
    expect(evaluateExpectation(analysis, { parallelAgents: ["scout", "reviewer"] })).toEqual({
      passed: true,
      reasons: [],
    });
  });

  test("rejects a decision that starts before evidence settles", () => {
    const analysis = analyzeJsonl([
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "run", agent: "scout" } }),
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "run", agent: "reviewer" } }),
      line({ type: "tool_execution_end", toolName: "subagent", result: { content: [{ type: "text", text: "# Evidence\\nlocal" }] } }),
    ].join("\n"));
    expect(evaluateExpectation(analysis, {
      agentsBefore: { agents: ["scout"], before: "reviewer" },
    }).passed).toBe(false);
  });

  test("requires every prerequisite subagent to settle before a dependent decision", () => {
    const analysis = analyzeJsonl([
      line({ type: "tool_execution_start", toolCallId: "scout-call", toolName: "subagent", args: { action: "run", agent: "scout" } }),
      line({ type: "tool_execution_start", toolCallId: "test-call", toolName: "subagent", args: { action: "run", agent: "tester" } }),
      line({ type: "tool_execution_end", toolCallId: "scout-call", toolName: "subagent", isError: false }),
      line({ type: "tool_execution_start", toolCallId: "review-call", toolName: "subagent", args: { action: "run", agent: "reviewer" } }),
    ].join("\n"));

    expect(evaluateExpectation(analysis, {
      agentsBefore: { agents: ["scout", "tester"], before: "reviewer" },
    })).toEqual({
      passed: false,
      reasons: ["tester did not settle before reviewer started"],
    });
  });

  test("checks required structured handoff sections", () => {
    const analysis = analyzeJsonl([
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "run", agent: "scout" } }),
      line({ type: "tool_execution_end", toolName: "subagent", result: { content: [{ type: "text", text: "- Evidence: local\n- Validation: passed\n- Blockers: none\n- Risks: none" }] } }),
    ].join("\n"));
    expect(evaluateExpectation(analysis, {
      handoffFields: ["evidence", "validation", "blockers", "risks"],
    })).toEqual({ passed: true, reasons: [] });
  });

  test("extracts handoff sections from the JSON envelope returned by subagent", () => {
    const analysis = analyzeJsonl([
      line({ type: "tool_execution_start", toolName: "subagent", args: { action: "run", agent: "worker" } }),
      line({
        type: "tool_execution_end",
        toolName: "subagent",
        result: {
          content: [{
            type: "text",
            text: JSON.stringify({ summary: "## Evidence\nchanged files\n\n## Validation\npassed\n\n## Blockers\nNone\n\n## Risks\nNone" }),
          }],
        },
      }),
    ].join("\n"));

    expect(evaluateExpectation(analysis, {
      handoffFields: ["evidence", "validation", "blockers", "risks"],
    })).toEqual({ passed: true, reasons: [] });
  });

  test("allows independent evidence agents in either order before a decision agent", () => {
    const analysis = analyzeJsonl([
      line({ type: "tool_execution_start", toolCallId: "test", toolName: "subagent", args: { action: "run", agent: "tester" } }),
      line({ type: "tool_execution_start", toolCallId: "scout", toolName: "subagent", args: { action: "run", agent: "scout" } }),
      line({ type: "tool_execution_end", toolCallId: "test", toolName: "subagent", isError: false }),
      line({ type: "tool_execution_end", toolCallId: "scout", toolName: "subagent", isError: false }),
      line({ type: "tool_execution_start", toolCallId: "review", toolName: "subagent", args: { action: "run", agent: "reviewer" } }),
    ].join("\n"));

    expect(evaluateExpectation(analysis, {
      requiredAgents: ["scout", "tester", "reviewer"],
      agentsBefore: { agents: ["scout", "tester"], before: "reviewer" },
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
