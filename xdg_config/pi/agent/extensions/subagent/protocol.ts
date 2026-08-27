export interface SubagentExecutionProfile {
  name: string;
  systemPrompt: string;
  model?: string;
  thinking?: string;
  tools: string[];
}

export interface SubagentWorkOrder {
  goal: string;
  scope: string[];
  context?: string;
  nonGoals?: string[];
  constraints: string[];
  knownDecisions: Array<{ statement: string; source: "user" | "parent" | "code" | "docs" }>;
  evidence: Array<{ kind: "file" | "command" | "url"; value: string }>;
  validation: string[];
  returnFormat: string;
  projectGuidance: string[];
}

export interface SubagentToolProgressItem {
  id: string;
  summary: string;
  status: "running" | "completed" | "failed";
}

/** A bounded, redacted slice of assistant reasoning captured between tool calls. */
export interface SubagentThinkingSegment {
  text: string;
}

/** Ordered interleaving of tool calls and thinking segments for timeline rendering. */
export type SubagentTimelineEntry =
  | { kind: "tool"; id: string; summary: string; status: SubagentToolProgressItem["status"] }
  | { kind: "thinking"; text: string };

/** A bounded decision request the child raises when it needs parent input to proceed. */
export interface SubagentDecision {
  question: string;
  options?: string[];
}

export interface SubagentProgress {
  summary: string;
  /** Bounded, operation-local tool lifecycle snapshot for renderer observability. */
  tools?: {
    earlierCount: number;
    history: SubagentToolProgressItem[];
    active: SubagentToolProgressItem[];
  };
  /** Bounded, event-ordered timeline interleaving tool calls and thinking segments. */
  timeline?: SubagentTimelineEntry[];
  /** True only when this progress update carries a decision the parent must answer. */
  needsDecision?: boolean;
  /** Bounded decision payload surfaced alongside a needsDecision update. */
  decision?: SubagentDecision;
}

export interface SubagentRunOptions {
  cwd: string;
  agent: SubagentExecutionProfile;
  workOrder: SubagentWorkOrder;
  runId: string;
  operationId: string;
  parentSessionId: string;
  deadlineMs: number;
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

export type SubagentExecutor = (options: SubagentRunOptions) => Promise<SubagentResult>;

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
  steer(expectedOperationId: string, message: string): Promise<boolean>;
  interrupt(expectedOperationId: string): Promise<boolean>;
  close(): Promise<void>;
}

export type SubagentControllerFactory = (initial: SubagentRunOptions) => Promise<SubagentController>;

/** Provider-stripped model id for compact labels ("openai/gpt-5" -> "gpt-5"). */
export function stripModel(model: string): string {
  const slash = model.lastIndexOf("/");
  return slash === -1 ? model : model.slice(slash + 1);
}
