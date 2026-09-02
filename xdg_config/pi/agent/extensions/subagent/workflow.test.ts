import { describe, expect, test } from "vitest";
import { createWorkflowRecord, executeWorkflow, validateWorkflowNodes, workflowSnapshot, type WorkflowNodeRecord } from "./workflow.ts";

const nodes = [
  { id: "local", agent: "scout", objective: "Inspect" },
  { id: "research", agent: "researcher", objective: "Research" },
  { id: "design", agent: "oracle", objective: "Design", dependsOn: ["local", "research"] },
  { id: "implement", agent: "worker", objective: "Implement", dependsOn: ["design"] },
  { id: "test", agent: "tester", objective: "Test", dependsOn: ["implement"] },
  { id: "review", agent: "reviewer", objective: "Review", dependsOn: ["implement"] },
];

describe("workflow DAG", () => {
  test("rejects duplicate, missing, self, and cyclic dependencies", () => {
    expect(validateWorkflowNodes([])).toContain("workflow requires at least one node");
    expect(validateWorkflowNodes([
      { id: "a", agent: "scout", objective: "A", dependsOn: ["b"] },
      { id: "b", agent: "scout", objective: "B", dependsOn: ["a"] },
      { id: "b", agent: "scout", objective: "duplicate", dependsOn: ["missing", "b"] },
    ])).toEqual(expect.arrayContaining([
      "duplicate workflow node id: b",
      "workflow node b depends on unknown node missing",
      "workflow node b cannot depend on itself",
      expect.stringContaining("dependency cycle"),
    ]));
  });

  test("runs independent nodes in parallel and passes settled dependencies to barriers", async () => {
    const record = createWorkflowRecord({ workflowId: "wf", index: 1, objective: "Ship", background: false, nodes });
    const starts: string[] = [];
    const upstream = new Map<string, string[]>();
    const gates = new Map<string, () => void>();
    const runNode = (node: WorkflowNodeRecord, inputs: WorkflowNodeRecord[]) => new Promise<any>((resolve) => {
      starts.push(node.spec.id);
      upstream.set(node.spec.id, inputs.map((input) => input.spec.id));
      gates.set(node.spec.id, () => resolve({ status: "completed", handoff: { agent: node.spec.agent, status: "completed", summary: node.spec.id, transcript: {} } }));
    });
    const running = executeWorkflow(record, { canStart: () => true, runNode });
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(starts).toEqual(["local", "research"]);
    gates.get("local")!();
    gates.get("research")!();
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(starts).toContain("design");
    expect(upstream.get("design")).toEqual(["local", "research"]);
    gates.get("design")!();
    await new Promise((resolve) => setTimeout(resolve, 0));
    gates.get("implement")!();
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(starts.slice(-2).sort()).toEqual(["review", "test"]);
    gates.get("test")!();
    gates.get("review")!();
    await running;
    expect(workflowSnapshot(record).status).toBe("completed");
  });

  test("skips blocked descendants but allows explicit failure consumers", async () => {
    const record = createWorkflowRecord({
      workflowId: "wf", index: 1, objective: "Ship", background: false,
      nodes: [
        { id: "first", agent: "scout", objective: "Fail" },
        { id: "blocked", agent: "worker", objective: "Blocked", dependsOn: ["first"] },
        { id: "diagnose", agent: "reviewer", objective: "Diagnose", dependsOn: ["first"], runOnDependencyFailure: true },
      ],
    });
    const starts: string[] = [];
    await executeWorkflow(record, {
      canStart: () => true,
      async runNode(node) {
        starts.push(node.spec.id);
        return { status: node.spec.id === "first" ? "failed" : "completed", error: node.spec.id === "first" ? "failed" : undefined };
      },
    });
    expect(starts).toEqual(["first", "diagnose"]);
    expect(record.nodes.get("blocked")?.status).toBe("skipped");
    expect(record.status).toBe("failed");
  });

  test("interrupts pending work", async () => {
    const record = createWorkflowRecord({ workflowId: "wf", index: 1, objective: "Stop", background: false, nodes: [nodes[0]!] });
    const running = executeWorkflow(record, {
      canStart: () => false,
      async runNode() { return { status: "completed" }; },
    });
    record.controller.abort();
    await running;
    expect(record.status).toBe("interrupted");
    expect(record.nodes.get("local")?.status).toBe("skipped");
  });

  test("bounds the complete twenty-node snapshot", () => {
    const record = createWorkflowRecord({
      workflowId: "wf", index: 1, objective: "x".repeat(20_000), background: false,
      nodes: Array.from({ length: 20 }, (_, index) => ({ id: `node${index}`, agent: "scout", objective: "o".repeat(10_000) })),
    });
    for (const node of record.nodes.values()) {
      node.status = "completed";
      node.result = {
        status: "completed",
        handoff: {
          agent: "scout", status: "completed", summary: "s".repeat(20_000), changes: "c".repeat(20_000),
          evidence: "e".repeat(20_000), validation: "v".repeat(20_000), risks: "r".repeat(20_000),
          transcript: { sessionId: "i".repeat(1_000), sessionPath: "/" + "p".repeat(2_000) },
        },
      };
    }
    expect(JSON.stringify(workflowSnapshot(record)).length).toBeLessThan(32_000);
  });
});
