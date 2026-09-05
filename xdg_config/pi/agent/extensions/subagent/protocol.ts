export interface SubagentExecutionProfile {
  name: string;
  systemPrompt: string;
  model?: string;
  thinking?: string;
  tools: string[];
}

export interface SubagentWorkOrder {
  task: string;
  cwd: string;
  instructions: string[];
  projectGuidance: string[];
}

export interface SubagentToolProgressItem {
  id: string;
  summary: string;
  status: "running" | "completed" | "failed";
}

/** Ordered interleaving of tool calls and thinking segments for timeline rendering. */
export type SubagentTimelineEntry =
  | { kind: "tool"; id: string; summary: string; status: SubagentToolProgressItem["status"] }
  | { kind: "thinking"; text: string };

/**
 * Current live activity state emitted at thinking/tool boundaries for the
 * unified activity center and bounded diagnostics.
 *
 * - `thinking` "running" means reasoning deltas are still streaming (unflushed):
 *   the activity center shows `Thinking…` below the job-level spinner.
 * - `thinking` "completed" means the segment was just flushed into a settled
 *   timeline entry: the activity center shows the completed `✓ Thinking` marker.
 * - `tool` reflects the active/last tool call lifecycle for the current item.
 *   It is omitted outside these boundaries (e.g. while writing the response).
 */
export type SubagentActivityPhase =
  | { kind: "thinking"; status: "running" | "completed" }
  | { kind: "tool"; status: SubagentToolProgressItem["status"] };

/** Shared live affordance glyphs for activity and terminal renderers. */
export const SUBAGENT_SPINNER_GLYPH = "⠋";
export const SUBAGENT_DONE_GLYPH = "✓";
export const SUBAGENT_FAILED_GLYPH = "✗";

/**
 * Full spinner frame cycle shared by live renderers (first frame is
 * SUBAGENT_SPINNER_GLYPH) so the widget and result animation stay consistent.
 */
export const SUBAGENT_SPINNER_FRAMES = [SUBAGENT_SPINNER_GLYPH, "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

export interface SubagentProgress {
  summary: string;
  /** Explicit thinking/tool boundary state for live renderers; omitted otherwise. */
  phase?: SubagentActivityPhase;
  /** Bounded, operation-local tool lifecycle snapshot for renderer observability. */
  tools?: {
    earlierCount: number;
    history: SubagentToolProgressItem[];
    active: SubagentToolProgressItem[];
  };
  /** Bounded, event-ordered timeline interleaving tool calls and thinking segments. */
  timeline?: SubagentTimelineEntry[];
}

export interface SubagentRunOptions {
  cwd: string;
  agent: SubagentExecutionProfile;
  workOrder: SubagentWorkOrder;
  runId: string;
  operationId: string;
  parentSessionId: string;
  signal?: AbortSignal;
  onProgress?: (progress: string | SubagentProgress) => void;
}

export interface SubagentResult {
  runId: string;
  operationId: string;
  /** Identity of the concrete child process instance, when available. */
  processInstanceId?: string;
  agent: string;
  status: "completed" | "failed" | "interrupted";
  summary: string;
  transcript: {
    sessionId?: string;
    sessionPath?: string;
  };
}

export class SubagentCancellationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "SubagentCancellationError";
  }
}

export interface SubagentOperation {
  /** Resolves only after runtime state and prompt acceptance are authoritative. */
  accepted: Promise<void>;
  /** Resolves after the authoritative agent_settled event. */
  result: Promise<SubagentResult>;
}

/** Minimal reusable runtime contract consumed by the extension control plane. */
export interface SubagentController {
  readonly processInstanceId: string;
  readonly transcript: Readonly<SubagentResult["transcript"]>;
  /** Resolves if the owned process or RPC protocol fails before explicit close. */
  readonly failure: Promise<Error>;
  start(options: SubagentRunOptions): SubagentOperation;
  /** Convenience compatibility seam for direct controller callers. */
  submit?(options: SubagentRunOptions): Promise<SubagentResult>;
  interrupt(expectedOperationId: string): Promise<boolean>;
  close(): Promise<void>;
}

export type SubagentControllerFactory = (initial: SubagentRunOptions) => Promise<SubagentController>;

/** Provider-stripped model id for compact labels ("openai/gpt-5" -> "gpt-5"). */
export function stripModel(model: string): string {
  const slash = model.lastIndexOf("/");
  return slash === -1 ? model : model.slice(slash + 1);
}
