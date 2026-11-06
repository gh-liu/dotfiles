import { fileURLToPath } from "node:url";
import { Type } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { runSubagent } from "./runner.ts";
import { renderCall, renderResult } from "./renderer.ts";

export const subagent = defineTool({
  name: "subagent",
  label: "Subagent",
  description: `Delegate one bounded task to a fresh agent when context isolation outweighs handoff overhead, or the user requests it. Otherwise work directly; use codemode for scripted tool orchestration. Do not duplicate delegated work.

The child cannot see this conversation or prior calls; supply context and accessible file references. It loads project guidance and skills independently. Tools: read, write, edit, bash, codemode. Parent extensions, MCP tools, permission hooks and runtime-only provider configuration are not inherited.

Calls are synchronous, sequential and one-shot: no resume, background work or nested delegation. No total runtime/token/cost cap. The working directory, filesystem and shell environment are shared, not sandboxed. Specify read-only or write boundaries, preserve unrelated changes, avoid overlapping writes and carry user constraints/approvals into task. Never bypass approvals. Cancellation does not roll back changes.

Returns a concise handoff, not independent verification; check evidence and changes before relying on them. Output over 24,000 UTF-8 bytes or incomplete responses fail; failures return diagnostics, not necessarily the requested format. Read ${fileURLToPath(new URL("./README.md", import.meta.url))} for detailed usage and limits.`,
  promptSnippet: "Delegate a bounded task to an isolated agent context with a shared filesystem.",
  exposure: "model-only",
  executionMode: "sequential",
  parameters: Type.Object({
    description: Type.String({ minLength: 1, maxLength: 160, description: "Short task title for the UI." }),
    task: Type.String({ minLength: 1, description: "Self-contained brief: goal, facts/references, scope/non-goals, allowed write paths or read-only, user constraints/approvals, acceptance checks and required evidence. Specify deliverable format when needed; distinguish facts from hypotheses." }),
    model: Type.Optional(Type.String({ minLength: 3, description: "Inherits parent model. Override with a configured provider/model-id; unknown models fail without fallback." })),
    thinking: Type.Optional(Type.Union([
      Type.Literal("off"), Type.Literal("minimal"), Type.Literal("low"), Type.Literal("medium"),
      Type.Literal("high"), Type.Literal("xhigh"), Type.Literal("max"),
    ], { description: "Inherits parent thinking. Override for a clear task-specific benefit; user instructions win. Unsupported levels may be clamped." })),
  }),
  execute: (_id, params, signal, onUpdate, ctx) => runSubagent(params, signal, onUpdate, ctx),
  renderCall,
  renderResult,
});

export default function (pi: ExtensionAPI) {
  pi.registerTool(subagent);
}
