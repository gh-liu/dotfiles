import { Type } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { runSubagent } from "./runner.ts";
import { renderCall, renderResult } from "./renderer.ts";

export const subagent = defineTool({
  name: "subagent",
  label: "Subagent",
  description: "Delegate a bounded, context-heavy exploration or implementation task to a fresh child agent. Supply the necessary background, scope, constraints, acceptance criteria and expected evidence: the child cannot see this conversation. It shares this working directory and can read, run commands and modify files. Only its concise final handoff returns here. Use for large intermediate context, not simple lookups. No nested delegation or background execution.",
  promptSnippet: "Delegate context-heavy exploration or execution to an isolated child conversation.",
  exposure: "model-only",
  executionMode: "sequential",
  parameters: Type.Object({
    description: Type.String({ minLength: 1, maxLength: 160, description: "Short task title" }),
    task: Type.String({ minLength: 1, description: "Self-contained task with background, scope, constraints, acceptance criteria and required evidence. Prefer file references over pasted logs." }),
    thinking: Type.Optional(Type.Union([
      Type.Literal("off"), Type.Literal("minimal"), Type.Literal("low"), Type.Literal("medium"),
      Type.Literal("high"), Type.Literal("xhigh"), Type.Literal("max"),
    ], { description: "Default: inherit parent thinking. Override only for a clear task-specific benefit; user instructions win. Lower for bounded, low-risk, easily verified work; raise for uncertainty or complex reasoning. The model may clamp unsupported levels; the effective level is displayed." })),
  }),
  execute: (_id, params, signal, onUpdate, ctx) => runSubagent(params, signal, onUpdate, ctx),
  renderCall,
  renderResult,
});

export default function (pi: ExtensionAPI) {
  pi.registerTool(subagent);
}
