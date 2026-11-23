import { fileURLToPath } from "node:url";
import { Type } from "typebox";
import { StringEnum } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { runSubagent, type Thinking } from "./runner.ts";
import { renderCall, renderResult } from "./renderer.ts";

const THINKING_LEVELS = Object.keys({
  off: true, minimal: true, low: true, medium: true, high: true, xhigh: true, max: true,
} satisfies Record<Thinking, true>) as Thinking[];

const readmePath = fileURLToPath(new URL("./README.md", import.meta.url));

export const subagent = defineTool({
  name: "subagent",
  label: "Subagent",
  description: `Delegate one bounded task to a fresh isolated agent when context isolation outweighs handoff overhead, or when requested; otherwise work directly or use codemode. The child sees no prior conversation, shares the working directory/shell (changes persist on cancellation), and must never bypass user approvals—specify read-only or write boundaries in task. Read ${readmePath} before delegating for tools, model/thinking overrides, parallelism, and handoff limits.`,
  promptSnippet: "Delegate a bounded task to an isolated agent context with a shared filesystem.",
  exposure: "model-only",
  executionMode: "parallel",
  parameters: Type.Object({
    description: Type.String({ minLength: 1, maxLength: 160, description: "Short task title for the UI." }),
    task: Type.String({ minLength: 1, description: "Self-contained brief: goal, facts/references, scope/non-goals, allowed write paths or read-only, user constraints/approvals, acceptance checks and required evidence. Specify deliverable format when needed; distinguish facts from hypotheses." }),
    model: Type.Optional(Type.String({ minLength: 3, description: "Inherits parent model. Override with a configured provider/model-id; unknown models fail without fallback." })),
    thinking: Type.Optional(Type.Unsafe<Thinking>(StringEnum(THINKING_LEVELS, {
      description: "Inherits parent thinking. Override for a clear task-specific benefit; user instructions win. Unsupported levels may be clamped.",
    }))),
  }),
  execute: (_id, params, signal, onUpdate, ctx) => runSubagent(params, signal, onUpdate, ctx),
  renderCall,
  renderResult,
});

export default function (pi: ExtensionAPI) {
  pi.registerTool(subagent);
}
