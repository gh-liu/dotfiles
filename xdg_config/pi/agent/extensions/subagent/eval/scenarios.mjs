const ttlOutcome = [
  "(?:TTL|ttlSeconds).{0,100}(?:1000|millisecond|毫秒)",
  "(?:1000|millisecond|毫秒).{0,100}(?:TTL|ttlSeconds)",
];

export const scenarios = [
  {
    id: "simple-lookup",
    description: "A single-file lookup stays in the parent.",
    quick: true, repeats: 3, fixture: "baseline", workspace: "read-only", targetRate: 1,
    expectation: { maxSubagentCalls: 0, parentToolCounts: { read: { min: 1 } } },
    prompt: "Read src/session.js and tell me DEFAULT_TTL_SECONDS. This is a single-file lookup. Do not modify files.",
  },
  {
    id: "local-discovery",
    description: "Bounded multi-file discovery routes to scout.",
    quick: true, repeats: 3, fixture: "baseline", workspace: "read-only", targetRate: 2 / 3,
    expectation: { requiredAgents: ["scout"], maxSubagentCalls: 1, actionSequence: [{ action: "run" }] },
    prompt: "Delegate one scout to map the session lifecycle across src/session.js, src/handler.js, tests, and plan.md. Ask for cited evidence and the smallest change seam. Synthesize its result without repeating its reads. Do not modify files.",
  },
  {
    id: "external-research",
    description: "Scout owns source-heavy web research as well as local discovery.",
    quick: true, repeats: 3, fixture: "baseline", workspace: "read-only", targetRate: 2 / 3,
    expectation: { requiredAgents: ["scout"], maxSubagentCalls: 1, parentToolCounts: { web_search: { max: 0 } } },
    prompt: "Delegate one scout to research current authoritative Node.js guidance for testing time-dependent code with node:test. Require multiple primary-source URLs and a repository-specific recommendation. Do not search again in the parent or modify files.",
  },
  {
    id: "independent-review",
    description: "Fresh-eyes review routes to reviewer and reports the test gap.",
    quick: true, repeats: 1, fixture: "fixed-missing-test", workspace: "read-only", targetRate: 1,
    hardExpectation: { requiredAgents: ["reviewer"], maxSubagentCalls: 1 },
    expectation: {
      requiredAgents: ["reviewer"], maxSubagentCalls: 1,
      finalAny: ["(?:default|默认).{0,100}(?:TTL|60.second|regression|test|回归|测试)"],
    },
    prompt: "Delegate one reviewer for a fresh-eyes review of the uncommitted TTL fix against plan.md. Require severity and file/line evidence. Do not modify files.",
  },
  {
    id: "expert-judgment",
    description: "Reviewer also owns bounded expert judgment and tradeoff resolution.",
    quick: false, repeats: 1, fixture: "baseline", workspace: "read-only", targetRate: 1,
    expectation: {
      requiredAgents: ["reviewer"], maxSubagentCalls: 1,
      finalAny: ["epoch.{0,80}millisecond|keep.{0,40}epoch|AGENTS\\.md.{0,40}millisecond"],
    },
    prompt: "Delegate one reviewer to resolve this compatibility decision: while fixing TTL, should expiresAt stay epoch-millisecond or become an ISO string? It must inspect AGENTS.md and relevant code, recommend one option with evidence, and remain read-only.",
  },
  {
    id: "browser-qa",
    description: "Exploratory browser QA routes to tester.",
    quick: false, repeats: 1, fixture: "baseline", workspace: "qa", targetRate: 1,
    hardExpectation: { requiredAgents: ["tester"], maxSubagentCalls: 1 },
    expectation: { requiredAgents: ["tester"], maxSubagentCalls: 1, finalAny: ["Test Report|Coverage|QA|browser"] },
    prompt: "Delegate one tester to launch qa/server.js, exercise valid and empty User ID flows with agent-browser, inspect console/network failures, save .artifacts/tester-home.png, and clean up the server/browser. It may write only .artifacts and must not install anything or modify source. Synthesize its report.",
  },
  {
    id: "implementation",
    description: "Worker implements while the parent inspects the diff and reruns tests.",
    quick: true, repeats: 1, fixture: "baseline", workspace: "implementation", targetRate: 1,
    expectation: {
      requiredAgents: ["worker"], maxSubagentCalls: 1,
      parentToolCallsAfter: [
        { agent: "worker", tool: "bash", argsMatch: "git\\s+diff" },
        { agent: "worker", tool: "bash", argsMatch: "(?:npm\\s+test|node\\s+--test)" },
      ],
    },
    prompt: "Delegate one worker to implement plan.md, changing only src/session.js and test/session.test.js and running tests. After it settles, inspect the complete diff and rerun tests in the parent. Do not redo the implementation or commit.",
  },
  {
    id: "iterative-implementation",
    description: "One worker session delivers a staged implementation through acceptance-driven followup.",
    quick: false, repeats: 1, fixture: "baseline", workspace: "implementation", targetRate: 1,
    hardExpectation: {
      requiredAgents: ["worker"],
      actionSequence: [{ action: "run" }, { action: "followup" }, { action: "get" }, { action: "close" }],
    },
    expectation: {
      requiredAgents: ["worker"], maxSubagentCalls: 6,
      actionSequence: [{ action: "run" }, { action: "followup" }, { action: "get" }, { action: "close" }],
      parentToolCallsAfter: [
        { agent: "worker", tool: "bash", argsMatch: "git\\s+diff" },
        { agent: "worker", tool: "bash", argsMatch: "(?:npm\\s+test|node\\s+--test)" },
      ],
    },
    prompt: "Use one reusable worker session as an acceptance-driven workstream for plan.md. In its initial run, ask it to inspect the relevant code and implement only the production change in src/session.js, deliberately deferring test changes. Inspect that settled diff in the parent, then follow up on the same #N with the remaining acceptance gap: add the required regression coverage in test/session.test.js and run the focused tests. Inspect the complete diff and rerun the full test suite in the parent. If either inspection or validation exposes a defect, follow up on that same #N with only the concrete gap and re-check until accepted. Finally get and close the same session. Do not create another subagent, redo its implementation in the parent, or commit.",
  },
  {
    id: "parallel-investigation",
    description: "Independent scout and reviewer sessions start in parallel.",
    quick: false, repeats: 1, fixture: "baseline", workspace: "read-only", targetRate: 1,
    expectation: {
      requiredAgents: ["scout", "reviewer"], maxSubagentCalls: 2,
      parallelAgents: ["scout", "reviewer"], finalAny: ttlOutcome,
    },
    prompt: "Without editing, start two independent subagents in parallel in one turn: scout maps local TTL behavior and relevant external guidance; reviewer independently checks plan.md against the current implementation for correctness gaps. Synthesize both results without repeating their work.",
  },
  {
    id: "staged-delivery",
    description: "Parent visibly composes scout, worker, and reviewer sessions.",
    quick: false, repeats: 1, fixture: "baseline", workspace: "implementation", targetRate: 1,
    hardExpectation: { agentOrder: ["scout", "worker", "reviewer"] },
    expectation: { agentOrder: ["scout", "worker", "reviewer"] },
    prompt: "Complete plan.md with visible staged delegation: scout maps the seam; after its handoff, worker implements; after tests, reviewer reviews the diff. Pass relevant prior results in each later task, address blocking findings, verify the final diff/tests, close sessions, and do not commit.",
  },
  {
    id: "persistent-followup",
    description: "One session supports run, followup, get, and close.",
    quick: true, repeats: 1, fixture: "baseline", workspace: "read-only", targetRate: 1,
    hardExpectation: {
      requiredAgents: ["scout"],
      actionSequence: [{ action: "run" }, { action: "followup" }, { action: "get" }, { action: "close" }],
    },
    expectation: {
      requiredAgents: ["scout"], maxSubagentCalls: 4,
      actionSequence: [{ action: "run" }, { action: "followup" }, { action: "get" }, { action: "close" }],
    },
    prompt: "Exercise one reusable scout session. Run it to map createSession, then follow up on the same #N asking it to compare tests with plan.md. Get that same session, close it, and summarize. Do not create a second session or modify files.",
  },
  {
    id: "background-recovery",
    description: "Background run returns a ref and get recovers its result before close.",
    quick: false, repeats: 1, fixture: "baseline", workspace: "read-only", targetRate: 1,
    hardExpectation: {
      requiredAgents: ["scout"],
      actionSequence: [{ action: "run", background: true }, { action: "get" }, { action: "close" }],
    },
    expectation: {
      requiredAgents: ["scout"], maxSubagentCalls: 3,
      actionSequence: [{ action: "run", background: true }, { action: "get" }, { action: "close" }],
    },
    prompt: "Start one scout in background to inspect the TTL call flow. Continue independently with no repository reads, then use get with a wait on its #N to recover the result and close the session. Do not modify files.",
  },
  {
    id: "capacity-exhaustion",
    description: "Five turns reserve capacity and a sixth is rejected.",
    quick: false, repeats: 1, fixture: "baseline", workspace: "read-only", targetRate: 1,
    hardExpectation: {
      maxSubagentCalls: 6,
      parallelAgents: ["scout", "reviewer", "tester", "worker"],
      expectedSubagentErrors: [{ pattern: "Subagent capacity unavailable: maxConcurrentRuns is 5\\.", count: 1 }],
    },
    expectation: { maxSubagentCalls: 6, finalAny: ["capacity|concurrent|5"] },
    prompt: "In one turn start exactly six independent background runs in parallel: two scouts, two reviewers, one tester, and one worker, all read-only inspection tasks. Exactly five should be accepted and the sixth should hit maxConcurrentRuns=5. Report the capacity result, retrieve accepted results, and close accepted sessions. Do not retry or modify files.",
  },
];
