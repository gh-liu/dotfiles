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
  nonGoals?: string[];
  constraints: string[];
  knownDecisions: Array<{ statement: string; source: "user" | "parent" | "code" | "docs" }>;
  evidence: Array<{ kind: "file" | "command" | "url"; value: string }>;
  validation: string[];
  returnFormat: string;
  projectGuidance: string[];
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
  onProgress?: (summary: string) => void;
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
  submit(options: SubagentRunOptions): Promise<SubagentResult>;
  interrupt(expectedOperationId: string): Promise<boolean>;
  close(): Promise<void>;
}

export type SubagentControllerFactory = (initial: SubagentRunOptions) => Promise<SubagentController>;
