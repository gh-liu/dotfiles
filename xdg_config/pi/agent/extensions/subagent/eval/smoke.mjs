#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const MODEL = "openrouter/openrouter/free";
const EXPECTED_TASK = "Read owner.txt and return only the OWNER value.";
const EXPECTED_HANDOFF = "SessionRepository";

function textContent(message) {
  return Array.isArray(message?.content)
    ? message.content.filter((part) => part?.type === "text").map((part) => part.text).join("\n")
    : "";
}

function parseJsonl(source) {
  return source.split(/\r?\n/u).filter(Boolean).map((line, index) => {
    try {
      return JSON.parse(line);
    } catch (error) {
      throw new Error(`Malformed Pi JSONL at line ${index + 1}: ${error.message}`);
    }
  });
}

const fixture = mkdtempSync(join(tmpdir(), "pi-subagent-v2-smoke-"));
try {
  writeFileSync(join(fixture, "owner.txt"), `OWNER=${EXPECTED_HANDOFF}\n`);
  const prompt = `Call subagent exactly once with only this task argument: ${JSON.stringify(EXPECTED_TASK)} Then return only that value.`;
  const run = spawnSync("pi", [
    "--mode", "json",
    "--print",
    "--no-session",
    "--approve",
    "--model", MODEL,
    "--thinking", "minimal",
    "--tools", "subagent",
    prompt,
  ], { cwd: fixture, encoding: "utf8", timeout: 60_000 });

  if (run.error) throw run.error;
  if (run.status !== 0) throw new Error(`Pi exited ${run.status}: ${run.stderr.trim()}`);
  const events = parseJsonl(run.stdout);
  const starts = events.filter((event) =>
    event.type === "tool_execution_start" && event.toolName === "subagent");
  const ends = events.filter((event) =>
    event.type === "tool_execution_end" && event.toolName === "subagent");
  const assistants = events
    .filter((event) => event.type === "message_end" && event.message?.role === "assistant")
    .map((event) => event.message);
  const final = assistants.at(-1);
  const finalText = textContent(final);

  if (starts.length !== 1) throw new Error(`Expected one subagent call, received ${starts.length}.`);
  if (JSON.stringify(starts[0].args) !== JSON.stringify({ task: EXPECTED_TASK })) {
    throw new Error(`Unexpected public arguments: ${JSON.stringify(starts[0].args)}`);
  }
  if (ends.length !== 1 || ends[0].isError === true || ends[0].result?.isError === true) {
    throw new Error("The subagent tool did not complete successfully.");
  }
  if (final?.stopReason !== "stop") {
    throw new Error(`Final assistant stopReason was ${JSON.stringify(final?.stopReason)}.`);
  }
  if (finalText.trim() !== EXPECTED_HANDOFF) {
    throw new Error(`Unexpected final handoff: ${JSON.stringify(finalText)}`);
  }

  process.stdout.write(`${JSON.stringify({
    status: "pass",
    requestedModel: final.model,
    responseModel: final.responseModel,
    subagentArgs: starts[0].args,
    handoff: finalText.trim(),
  }, null, 2)}\n`);
} finally {
  rmSync(fixture, { force: true, recursive: true });
}
