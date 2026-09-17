#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { cpSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const MODEL = "openrouter/openrouter/free";
const TOOLS = "subagent,read,grep,find,ls,bash,edit,write";

const scenarios = [
  {
    id: "simple-lookup",
    expected: "0 calls",
    minCalls: 0,
    maxCalls: 0,
    prompt: "Read facts/single.txt and report the VALUE. This is a small direct lookup. Do not modify files.",
  },
  {
    id: "implicit-multifile-discovery",
    expected: "1 call",
    minCalls: 1,
    maxCalls: 1,
    prompt: "Keep this context focused on synthesis. Obtain a fresh-context investigation of the authentication ownership flow across src/auth.js, src/handler.js, and test/auth.test.js, then summarize the ownership boundary with file evidence. Do not modify files.",
  },
  {
    id: "independent-review",
    expected: "1 call",
    minCalls: 1,
    maxCalls: 1,
    prompt: "Have an independent context review the current uncommitted change against README.md and the tests. Report only material correctness gaps with file evidence. Do not modify files and do not redo the review in the parent.",
  },
  {
    id: "bounded-implementation",
    expected: "1 call",
    minCalls: 1,
    maxCalls: 1,
    prompt: "Delegate one bounded implementation task: fix the explicit TTL seconds-to-milliseconds bug in src/session.js, add the missing default-TTL regression in test/session.test.js, and run node --test. After the handoff, report the result without reimplementing it yourself. Do not commit.",
  },
  {
    id: "parallel-investigation",
    expected: "2 parallel calls",
    minCalls: 2,
    maxCalls: 2,
    parallel: true,
    prompt: "Start exactly two independent subagent calls in parallel in one turn. One should inspect authentication ownership across src/auth.js and src/handler.js. The other should independently inspect test coverage in test/auth.test.js. Then synthesize both handoffs. Do not modify files.",
  },
  {
    id: "coherent-direct-change",
    expected: "0 calls",
    minCalls: 0,
    maxCalls: 0,
    prompt: "Directly change the greeting in src/greeting.js from hello to hello-world and verify it with node --test test/greeting.test.js. This is one small coherent edit; do not delegate it. Do not commit.",
  },
];
const requestedIds = new Set(process.argv.slice(2));
const selectedScenarios = requestedIds.size === 0
  ? scenarios
  : scenarios.filter((scenario) => requestedIds.has(scenario.id));
if (selectedScenarios.length !== (requestedIds.size || scenarios.length)) {
  const known = new Set(scenarios.map((scenario) => scenario.id));
  const unknown = [...requestedIds].filter((id) => !known.has(id));
  throw new Error(`Unknown scenario(s): ${unknown.join(", ")}`);
}

function createTemplate(directory) {
  const files = {
    "README.md": "Session expiry remains an epoch-millisecond number.\n",
    "facts/single.txt": "VALUE=direct-17\n",
    "src/auth.js": "export function validate(token) { return token === 'valid-token'; }\n",
    "src/handler.js": "import { validate } from './auth.js';\nexport function handle(token) { return validate(token) ? 200 : 401; }\n",
    "src/session.js": "export function expiresAt(now, ttlSeconds = 60) { return now + ttlSeconds; }\n",
    "src/greeting.js": "export const greeting = 'hello';\n",
    "test/auth.test.js": "// Missing the invalid-token boundary test.\nimport { strict as assert } from 'node:assert';\nimport { validate } from '../src/auth.js';\nassert.equal(validate('valid-token'), true);\n",
    "test/session.test.js": "import test from 'node:test';\nimport assert from 'node:assert/strict';\nimport { expiresAt } from '../src/session.js';\ntest('explicit TTL', () => assert.equal(expiresAt(1000, 2), 3000));\n",
    "test/greeting.test.js": "import test from 'node:test';\nimport assert from 'node:assert/strict';\nimport { greeting } from '../src/greeting.js';\ntest('greeting', () => assert.equal(greeting, 'hello-world'));\n",
    "package.json": "{\"type\":\"module\"}\n",
  };
  for (const [path, content] of Object.entries(files)) {
    const destination = join(directory, path);
    mkdirSync(join(destination, ".."), { recursive: true });
    writeFileSync(destination, content);
  }
  spawnSync("git", ["init", "--quiet"], { cwd: directory });
  spawnSync("git", ["add", "."], { cwd: directory });
  spawnSync("git", ["-c", "user.name=Pi Eval", "-c", "user.email=pi@example.invalid", "commit", "--quiet", "-m", "baseline"], { cwd: directory });
  writeFileSync(join(directory, "src/session.js"), "export function expiresAt(now, ttlSeconds = 60) { return now + ttlSeconds * 1000; }\n");
}

function parseJsonl(source) {
  return source.split(/\r?\n/u).filter(Boolean).map((line) => JSON.parse(line));
}

function assistantText(message) {
  return Array.isArray(message?.content)
    ? message.content.filter((part) => part?.type === "text").map((part) => part.text).join("\n")
    : "";
}

const root = mkdtempSync(join(tmpdir(), "pi-subagent-trigger-"));
const template = join(root, "template");
mkdirSync(template);
createTemplate(template);

const reports = [];
try {
  for (const scenario of selectedScenarios) {
    const cwd = join(root, scenario.id);
    cpSync(template, cwd, { recursive: true });
    if (scenario.id !== "independent-review") {
      spawnSync("git", ["checkout", "--", "src/session.js"], { cwd });
    }
    const run = spawnSync("pi", [
      "--mode", "json", "--print", "--no-session", "--approve",
      "--model", MODEL, "--thinking", "minimal", "--tools", TOOLS,
      scenario.prompt,
    ], { cwd, encoding: "utf8", timeout: 120_000 });

    const report = {
      id: scenario.id,
      expected: scenario.expected,
      processStatus: run.status,
      signal: run.signal,
      error: run.error?.message,
    };
    try {
      const events = parseJsonl(run.stdout);
      const starts = events
        .map((event, index) => ({ event, index }))
        .filter(({ event }) => event.type === "tool_execution_start" && event.toolName === "subagent");
      const ends = events
        .map((event, index) => ({ event, index }))
        .filter(({ event }) => event.type === "tool_execution_end" && event.toolName === "subagent");
      const firstEnd = ends[0]?.index ?? -1;
      const toolErrors = ends
        .filter(({ event }) => event.isError === true || event.result?.isError === true)
        .map(({ event }) => ({
          toolCallId: event.toolCallId,
          text: Array.isArray(event.result?.content)
            ? event.result.content.filter((part) => part?.type === "text").map((part) => part.text).join("\n")
            : "",
        }));
      const assistants = events
        .filter((event) => event.type === "message_end" && event.message?.role === "assistant")
        .map((event) => event.message);
      const final = assistants.at(-1);
      const status = spawnSync("git", ["status", "--short"], { cwd, encoding: "utf8" }).stdout.trim().split(/\r?\n/u).filter(Boolean);
      Object.assign(report, {
        calls: starts.length,
        args: starts.map(({ event }) => event.args),
        parallel: starts.length > 1 && firstEnd >= 0 && starts.every(({ index }) => index < firstEnd),
        callPolicyPass: starts.length >= scenario.minCalls
          && starts.length <= scenario.maxCalls
          && toolErrors.length === 0
          && (!scenario.parallel || (firstEnd >= 0 && starts.every(({ index }) => index < firstEnd))),
        toolErrors,
        stopReason: final?.stopReason,
        responseModel: final?.responseModel,
        finalText: assistantText(final).slice(0, 500),
        changed: status,
      });
    } catch (error) {
      report.analysisError = error.message;
      report.stderr = run.stderr.slice(0, 500);
    }
    reports.push(report);
    process.stdout.write(`${JSON.stringify(report)}\n`);
  }
} finally {
  rmSync(root, { force: true, recursive: true });
}

const summary = {
  model: MODEL,
  callPolicyPassed: reports.filter((report) => report.callPolicyPass && report.stopReason === "stop").length,
  total: selectedScenarios.length,
  reports,
};
process.stdout.write(`\n${JSON.stringify(summary, null, 2)}\n`);
