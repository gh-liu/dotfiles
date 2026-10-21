import { createServer, type ServerResponse } from "node:http";
import { mkdtemp, mkdir, writeFile, readFile, rm, access } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import {
  createAgentSession, DefaultResourceLoader, ModelRuntime, SessionManager, SettingsManager,
  type ExtensionToolContext,
} from "@earendil-works/pi-coding-agent";
import { subagent } from "./index.ts";

let root: string;
let agentDir: string;
let requests: any[];
let respond: (body: any, response: ServerResponse) => void;
const server = createServer(async (request, response) => {
  let raw = "";
  for await (const chunk of request) raw += chunk;
  const body = JSON.parse(raw);
  requests.push(body);
  respond(body, response);
});

function answer(response: ServerResponse, delta: object, finish = "stop") {
  response.writeHead(200, { "content-type": "text/event-stream" });
  for (const chunk of [
    { choices: [{ index: 0, delta: { role: "assistant", ...delta }, finish_reason: null }] },
    { choices: [{ index: 0, delta: {}, finish_reason: finish }] },
  ]) response.write(`data: ${JSON.stringify({ id: "test", object: "chat.completion.chunk", model: "test", ...chunk })}\n\n`);
  response.end("data: [DONE]\n\n");
}

function tool(response: ServerResponse, name: string, args: object) {
  answer(response, { tool_calls: [{ index: 0, id: "child-tool", type: "function", function: { name, arguments: JSON.stringify(args) } }] }, "tool_calls");
}

beforeEach(async () => {
  root = await mkdtemp(join(tmpdir(), "pi-subagent-"));
  agentDir = join(root, "agent");
  await mkdir(agentDir);
  vi.stubEnv("PI_CODING_AGENT_DIR", agentDir);
  vi.stubEnv("PI_OFFLINE", "1");
  requests = [];
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address() as { port: number };
  await writeFile(join(agentDir, "models.json"), JSON.stringify({ providers: { fixture: {
    api: "openai-completions", baseUrl: `http://127.0.0.1:${address.port}/v1`, apiKey: "fixture-key",
    models: [{ id: "test", contextWindow: 128000, maxTokens: 4096 }],
  } } }));
  await writeFile(join(agentDir, "settings.json"), JSON.stringify({ retry: { enabled: false } }));
});

afterEach(async () => {
  server.closeAllConnections();
  await new Promise<void>((resolve) => server.close(() => resolve()));
  vi.unstubAllEnvs();
  await rm(root, { recursive: true, force: true });
});

async function context() {
  const runtime = await ModelRuntime.create({ modelsPath: join(agentDir, "models.json"), authPath: join(agentDir, "auth.json") });
  return { cwd: root, model: runtime.getModel("fixture", "test")!, thinkingLevel: "off", isProjectTrusted: () => false } as ExtensionToolContext;
}

test("real parent/child sessions isolate tool output, preserve guidance and return only the handoff", async () => {
  await writeFile(join(root, "fixture.txt"), "CHILD_TOOL_OUTPUT_SENTINEL");
  await writeFile(join(agentDir, "APPEND_SYSTEM.md"), "GLOBAL_APPEND_SENTINEL");
  await mkdir(join(root, ".pi"));
  await writeFile(join(root, ".pi", "APPEND_SYSTEM.md"), "UNTRUSTED_APPEND_SENTINEL");
  await mkdir(join(agentDir, "extensions"));
  await writeFile(join(agentDir, "extensions", "must-not-load.ts"), `throw new Error("PARENT_EXTENSION_LOADED");`);
  const handoff = "## Goal\nOutcome: Verified the fixture.\n## Progress\n### Done\n- [x] Read fixture.txt.\n## Critical Context\nThe fixture is valid.";
  respond = (body, response) => {
    const parent = JSON.stringify(body.messages).includes("PARENT_PRIVATE_SENTINEL");
    if (parent) {
      if (body.messages.some((message: any) => message.role === "tool")) answer(response, { content: "Parent received the handoff." });
      else tool(response, "subagent", { description: "Inspect fixture", task: "CHILD_TASK: inspect fixture.txt" });
    } else if (body.messages.some((message: any) => message.role === "tool")) answer(response, { content: handoff });
    else tool(response, "read", { path: "fixture.txt" });
  };
  const ctx = await context();
  const settings = SettingsManager.create(root, agentDir, { projectTrusted: false });
  const loader = new DefaultResourceLoader({ cwd: root, agentDir, settingsManager: settings, noExtensions: true, noSkills: true });
  await loader.reload();
  const { session } = await createAgentSession({ cwd: root, agentDir, model: ctx.model,
    settingsManager: settings, resourceLoader: loader, sessionManager: SessionManager.inMemory(root),
    tools: ["subagent"], customTools: [subagent], thinkingLevel: "off" });
  try {
    await session.prompt("PARENT_PRIVATE_SENTINEL");
    const result = session.messages.find((message) => message.role === "toolResult") as any;
    expect(result.content).toEqual([{ type: "text", text: handoff }]);
    expect(result.details.status).toBe("ok");
    expect(result.details.calls).toMatchObject([{ name: "read", status: "ok" }]);
    const childRecord = await readFile(result.details.sessionFile, "utf8");
    expect(childRecord).toContain("CHILD_TOOL_OUTPUT_SENTINEL");
    expect(childRecord).not.toContain("PARENT_PRIVATE_SENTINEL");
    const parentNext = requests.at(-1);
    expect(JSON.stringify(parentNext)).not.toContain("CHILD_TOOL_OUTPUT_SENTINEL");
    expect(JSON.stringify(parentNext)).not.toContain("startedAt");
    expect(JSON.stringify(parentNext)).toContain(handoff.replace(/\n/g, "\\n"));
    const childFirst = requests.find((body) => !JSON.stringify(body).includes("PARENT_PRIVATE_SENTINEL"));
    expect(childFirst.tools.map((entry: any) => entry.function.name).sort()).toEqual(["bash", "edit", "find", "grep", "ls", "read", "write"]);
    expect(JSON.stringify(childFirst)).toContain("GLOBAL_APPEND_SENTINEL");
    expect(JSON.stringify(childFirst)).not.toContain("UNTRUSTED_APPEND_SENTINEL");
    expect(JSON.stringify(childFirst)).toContain("Outcome:");
  } finally { session.dispose(); }
}, 15000);

test("cancelling a running bash child waits for termination and prevents later file writes", async () => {
  respond = (_body, response) => tool(response, "bash", { command: "sleep 2; touch should-not-exist" });
  const controller = new AbortController();
  const updates: unknown[] = [];
  const result = await subagent.execute("cancel-test", { description: "Cancel", task: "Wait" }, controller.signal, (update) => {
    updates.push(update);
    if (update.details.calls.some((call) => call.status === "running")) controller.abort();
  }, await context());
  expect(result.isError).toBe(true);
  expect(result.details.status).toBe("cancelled");
  expect(result.details.calls[0]).toMatchObject({ name: "bash", status: "cancelled" });
  expect(result.content[0]).toMatchObject({ text: expect.stringContaining("no rollback") });
  // A detached command could return early yet still write after its original sleep.
  await new Promise((resolve) => setTimeout(resolve, 2100));
  await expect(access(join(root, "should-not-exist"))).rejects.toThrow();
  expect(updates.length).toBeGreaterThan(0);
}, 10000);

test("cancellation during asynchronous authentication cannot start a late child run", async () => {
  const config = JSON.parse(await readFile(join(agentDir, "models.json"), "utf8"));
  config.providers.fixture.apiKey = "!sleep 0.4; printf fixture-key";
  await writeFile(join(agentDir, "models.json"), JSON.stringify(config));
  const ctx = await context();
  const controller = new AbortController();
  respond = (_body, response) => answer(response, { content: "LATE_RUN" });
  const result = await subagent.execute("preflight", { description: "Preflight cancellation", task: "Do not start late" }, controller.signal,
    () => { setTimeout(() => controller.abort(), 30).unref(); }, ctx);
  expect(result.details.status).toBe("cancelled");
  expect(requests).toHaveLength(0);
  expect(await readFile(result.details.sessionFile!, "utf8")).toContain("Do not start late");
}, 10000);

test.each([
  { label: "oversized", output: "中".repeat(8100), stop: "stop", expected: "exceeds 24000 bytes" },
  { label: "incomplete", output: "Partial answer", stop: "length", expected: "ended with length" },
])("$label handoffs are saved but never reported as a complete success", async ({ output, stop, expected }) => {
  respond = (_body, response) => answer(response, { content: output }, stop);
  const result = await subagent.execute("bounds", { description: "Bounded result", task: "Return answer" }, undefined, undefined, await context());
  expect(result.isError).toBe(true);
  expect(result.details.status).toBe("error");
  expect(result.content[0]).toMatchObject({ text: expect.stringContaining(expected) });
  expect(result.content[0]).not.toMatchObject({ text: expect.stringContaining(output) });
  expect(await readFile(result.details.sessionFile!, "utf8")).toContain(output);
}, 10000);

test("an unknown parent model fails explicitly instead of selecting a default", async () => {
  const ctx = await context();
  ctx.model = { ...ctx.model!, provider: "dynamic-parent-only" };
  const result = await subagent.execute("unknown", { description: "No fallback", task: "Inspect" }, undefined, undefined, ctx);
  expect(result.isError).toBe(true);
  expect(result.content[0]).toMatchObject({ text: expect.stringContaining("Dynamic parent providers/routers are not inherited") });
  expect(requests).toHaveLength(0);
  expect(result.details.sessionFile).toBeUndefined();
});

test("long child activity and large arguments stay bounded without losing the independent record", async () => {
  await writeFile(join(root, "fixture.txt"), "Fixture");
  const large = "LARGE_ARGUMENT_".repeat(400);
  respond = (body, response) => {
    if (body.messages.some((message: any) => message.role === "tool")) {
      answer(response, { content: "## Goal\nOutcome: Read fixtures and wrote output.txt." });
    } else {
      const calls = Array.from({ length: 66 }, (_, index) => ({ index, id: `read-${index}`, type: "function",
        function: { name: "read", arguments: JSON.stringify({ path: "fixture.txt" }) } }));
      calls.push({ index: 66, id: "write", type: "function", function: { name: "write",
        arguments: JSON.stringify({ path: "output.txt", content: large }) } });
      answer(response, { tool_calls: calls }, "tool_calls");
    }
  };
  const result = await subagent.execute("activity", { description: "Bounded activity", task: "Read and write fixtures" }, undefined, undefined, await context());
  expect(result.isError).toBe(false);
  expect(result.details.calls).toHaveLength(64);
  expect(result.details.omitted).toBe(3);
  expect(result.details.calls.every((call) => call.status === "ok")).toBe(true);
  expect(JSON.stringify(result.details).length).toBeLessThan(20_000);
  expect(result.details.calls.at(-1)?.args).toContain("arguments shortened; see child session");
  expect(result.details.calls.every((call) => call.args.length <= 2048)).toBe(true);
  expect(await readFile(join(root, "output.txt"), "utf8")).toBe(large);
  expect(await readFile(result.details.sessionFile!, "utf8")).toContain(large);
}, 10000);

test.each([
  { parent: "high", requested: undefined, effective: "high" },
  { parent: "high", requested: "low", effective: "low" },
  { parent: "high", requested: "off", effective: "low" },
  { parent: "low", requested: "max", effective: "max" },
] as const)("thinking parent=$parent request=$requested becomes $effective", async ({ parent, requested, effective }) => {
  const config = JSON.parse(await readFile(join(agentDir, "models.json"), "utf8"));
  Object.assign(config.providers.fixture.models[0], {
    reasoning: true, thinkingLevelMap: { off: null, minimal: null, xhigh: "xhigh", max: "max" },
  });
  await writeFile(join(agentDir, "models.json"), JSON.stringify(config));
  const ctx = await context();
  ctx.thinkingLevel = parent;
  respond = (_body, response) => answer(response, { content: "## Goal\nOutcome: Verified." });
  const result = await subagent.execute("thinking", { description: "Thinking", task: "Verify", thinking: requested }, undefined, undefined, ctx);
  expect(result.isError).toBe(false);
  expect(result.details.requestedThinking).toBe(requested ?? parent);
  expect(result.details.effectiveThinking).toBe(effective);
  expect(requests[0].reasoning_effort).toBe(effective);
  expect(result.content[0]).toMatchObject({ text: requested === "off"
    ? expect.stringContaining("Thinking adjusted by model: off → low")
    : expect.not.stringContaining("Thinking adjusted") });
});

test("provider failures remain bounded while preserving a real diagnostic session", async () => {
  const diagnostic = "PROVIDER_DIAGNOSTIC_".repeat(4000);
  respond = (_body, response) => {
    response.writeHead(400, { "content-type": "application/json" });
    response.end(JSON.stringify({ error: { message: "Upstream failed", metadata: { raw: diagnostic } } }));
  };
  const result = await subagent.execute("error", { description: "Large error", task: "Verify" }, undefined, undefined, await context());
  expect(result.isError).toBe(true);
  const text = result.content.filter((part) => part.type === "text").map((part) => part.text).join("\n");
  expect(Buffer.byteLength(text)).toBeLessThanOrEqual(24_000);
  expect(text).toContain("shortened");
  expect(text).toContain("no rollback");
  expect(text).toContain(`Child session: ${result.details.sessionFile}`);
  expect(await readFile(result.details.sessionFile!, "utf8")).toContain(diagnostic);
});

test("parallel tool progress stays running after the first completion", async () => {
  respond = (body, response) => {
    if (body.messages.some((message: any) => message.role === "tool")) answer(response, { content: "## Goal\nOutcome: Both commands completed." });
    else answer(response, { tool_calls: [0.1, 0.8].map((seconds, index) => ({ index, id: `parallel-${index}`, type: "function",
      function: { name: "bash", arguments: JSON.stringify({ command: `sleep ${seconds}; printf done` }) } })) }, "tool_calls");
  };
  const updates: any[] = [];
  const result = await subagent.execute("parallel", { description: "Parallel activity", task: "Run independent commands" }, undefined,
    (update) => updates.push(update.details), await context());
  expect(result.isError).toBe(false);
  const intermediate = updates.find((update) => update.calls.some((call: any) => call.status === "ok") && update.running === 1);
  expect(intermediate?.activity).toBe("Running 1 tool…");
  expect(result.details.calls.map((call) => call.status)).toEqual(["ok", "ok"]);
  expect(result.details.running).toBe(0);
});
