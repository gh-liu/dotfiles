import { Type } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { runSubagent } from "./runner.ts";
import { renderCall, renderResult } from "./renderer.ts";

export const subagent = defineTool({
  name: "subagent",
  label: "Subagent",
  description: `Delegate one self-contained task that needs its own reasoning loop to a fresh agent conversation. Use when the child should interpret intermediate evidence, choose next steps and work toward a concrete outcome, while you only need a concise, verifiable handoff. Good fits: trace an unfamiliar behavior across files; investigate competing causes of a failure; implement and validate a scoped change; review a defined diff for specific risks. The outcome and scope must be clear; the solution and exploration path need not be known in advance.

Use codemode for tool orchestration you can express as code: batch or parallel calls, paginate, filter, aggregate, transform results, or run checks and return selected evidence for your own reasoning. Codemode executes your script; subagent delegates an agent's iterative interpretation and decisions. Large output, many files or many tool calls alone are not reasons to delegate. For example, extracting matching errors and counts from logs fits codemode; investigating their cause by following evidence through code and experiments can fit subagent. A child can also use codemode within its task.

Use direct tools for simple lookups or small coherent edits. Keep reasoning here when you need the raw details yourself, when the task needs frequent back-and-forth, or when it depends on parent-only tools/state. Delegate only when isolating the reasoning and exploration context is worth the briefing and handoff overhead. Do not duplicate an investigation you delegate.

The child cannot see this conversation, previous subagent calls, or attachments unless supplied as accessible file references. It loads applicable project guidance and skills independently. It uses the same model, with inherited or explicitly requested thinking; this is not a specialist model or a promise of lower cost. Its tools are read, write, edit, bash and codemode. Codemode is initialized independently and can call the child's file and shell tools; search and directory listing use bash. Parent extensions, MCP tools, permission hooks and runtime-only provider configuration are not inherited; do not assume a skill's required tools are available.

Execution is synchronous: you wait for the handoff, and subagent calls run sequentially. Each call starts fresh; there is no follow-up/resume API, background job or nested delegation. Scope tasks by deliverable, not an assumed time limit; no total runtime/token/cost cap is enforced.

The child shares the working directory, filesystem and shell environment. It can modify files and run installed commands, including network-capable commands through bash; context isolation is not a security sandbox. Specify read-only versus write scope, preserve unrelated changes, avoid overlapping writes, and carry all user constraints and approval requirements into the task. Never delegate to bypass an approval. Cancellation is cooperative and does not roll back changes.

Specify the expected deliverable and, when important, its format in task: a direct answer, findings list, comparison table, change report or structured data. Otherwise the child returns a concise, outcome-first handoff with necessary evidence, validation and unresolved issues, omitting empty sections. Compact-style continuation summaries are optional, not mandatory. Request exact paths/symbols and relevant results rather than raw tool output or thinking. Successful output is returned without runtime annotations; thinking adjustments stay in UI metadata. Returned text is limited to 24,000 UTF-8 bytes; oversized/incomplete responses fail explicitly. Failures return diagnostic text, not necessarily the requested format. Success means a handoff was returned, not that the task's acceptance criteria were independently verified. Inspect relevant changes/evidence and validate before relying on the result.`,
  promptSnippet: "Delegate a self-contained task needing iterative reasoning and evidence-driven next steps; use codemode for scripted tool orchestration and result filtering. Large output alone is not a trigger. Verify the concise handoff. Synchronous, shared filesystem, not a sandbox.",
  exposure: "model-only",
  executionMode: "sequential",
  parameters: Type.Object({
    description: Type.String({ minLength: 1, maxLength: 160, description: "Short, concrete task title for the UI; put the full instructions in task." }),
    task: Type.String({ minLength: 1, description: "Self-contained brief: desired outcome and why; relevant facts and file references; scope and non-goals; read-only or allowed write paths; user constraints and approval requirements; acceptance/validation criteria; required evidence and deliverable. Specify output format/detail when important (e.g. findings list, table, change report or strict JSON); otherwise expect a concise, outcome-first handoff, not a fixed template. Separate verified facts from hypotheses. Supply context the child cannot infer, not the parent transcript. Let the child choose its approach unless a method is required." }),
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
