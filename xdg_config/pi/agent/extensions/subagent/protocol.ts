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
