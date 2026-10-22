import { Type } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { runSubagent } from "./runner.ts";
import { renderCall, renderResult } from "./renderer.ts";

export const subagent = defineTool({
  name: "subagent",
  label: "Subagent",
  description: `Run one self-contained task in a fresh conversation so large intermediate context stays out of this conversation. Delegate when you can state a concrete outcome and review a concise handoff without needing the full exploration trace. Good fits: investigate a behavior across files and return evidence; diagnose a failure from long logs or test runs; implement and validate a scoped change; review a defined diff for specific risks. The solution need not be known in advance.

Use direct tools for simple lookups, small coherent edits, or work whose raw details you need to reason through yourself. Keep work here when it needs frequent back-and-forth or depends on parent-only tools/state. Do not duplicate an investigation you delegate.

The child cannot see this conversation, previous subagent calls, or attachments unless supplied as accessible file references. It loads applicable project guidance and skills independently. It uses the same model, with inherited or explicitly requested thinking; this is not a specialist model or a promise of lower cost. Its tools are read, write, edit, bash and codemode. Codemode is initialized independently and can call the child's file and shell tools; search and directory listing use bash. Parent extensions, MCP tools, permission hooks and runtime-only provider configuration are not inherited; do not assume a skill's required tools are available.

Execution is synchronous: you wait for the handoff, and subagent calls run sequentially. Each call starts fresh; there is no follow-up/resume API, background job or nested delegation. Scope tasks by deliverable, not an assumed time limit; no total runtime/token/cost cap is enforced.

The child shares the working directory, filesystem and shell environment. It can modify files and run installed commands, including network-capable commands through bash; context isolation is not a security sandbox. Specify read-only versus write scope, preserve unrelated changes, avoid overlapping writes, and carry all user constraints and approval requirements into the task. Never delegate to bypass an approval. Cancellation is cooperative and does not roll back changes.

Specify the expected deliverable and, when important, its format in task: a direct answer, findings list, comparison table, change report or structured data. Otherwise the child returns a concise, outcome-first handoff with necessary evidence, validation and unresolved issues, omitting empty sections. Compact-style continuation summaries are optional, not mandatory. Request exact paths/symbols and relevant results rather than raw tool output or thinking. Successful output is returned without runtime annotations; thinking adjustments stay in UI metadata. Returned text is limited to 24,000 UTF-8 bytes; oversized/incomplete responses fail explicitly. Failures return diagnostic text, not necessarily the requested format. Success means a handoff was returned, not that the task's acceptance criteria were independently verified. Inspect relevant changes/evidence and validate before relying on the result.`,
  promptSnippet: "Isolate context-heavy investigation, scoped implementation or verification; provide a self-contained task and verify its concise handoff. Synchronous, shared filesystem, not a sandbox.",
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
