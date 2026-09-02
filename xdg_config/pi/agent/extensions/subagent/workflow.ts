import { boundText, type ModelSubagentHandoff } from "./output.ts";

export type WorkflowStatus = "running" | "completed" | "failed" | "interrupted";
export type WorkflowNodeStatus = "pending" | "running" | "completed" | "failed" | "interrupted" | "skipped";

export interface WorkflowNodeSpec {
  id: string;
  agent: string;
  objective: string;
  dependsOn?: string[];
  runOnDependencyFailure?: boolean;
  scope?: string[];
  constraints?: string[];
  acceptance?: string[];
  context?: string;
  cwd?: string;
  exclusivePaths?: string[];
  toolBudget?: number;
}

export interface WorkflowNodeResult {
  jobId?: string;
  ref?: string;
  status: "completed" | "failed" | "interrupted";
  handoff?: ModelSubagentHandoff;
  error?: string;
}

export interface WorkflowNodeRecord {
  spec: WorkflowNodeSpec;
  status: WorkflowNodeStatus;
  runtimeJobId?: string;
  runtimeRef?: string;
  startedAt?: number;
  finishedAt?: number;
  result?: WorkflowNodeResult;
  error?: string;
}

export interface WorkflowRecord {
  workflowId: string;
  index: number;
  objective: string;
  status: WorkflowStatus;
  background: boolean;
  createdAt: number;
  nodes: Map<string, WorkflowNodeRecord>;
  controller: AbortController;
  settled: Promise<void>;
  settle(): void;
  finishedAt?: number;
  notificationDelivered?: boolean;
}

const NODE_ID = /^[a-z][a-z0-9_-]{0,39}$/;

export function validateWorkflowNodes(nodes: WorkflowNodeSpec[]): string[] {
  const errors: string[] = [];
  if (nodes.length === 0) errors.push("workflow requires at least one node");
  if (nodes.length > 20) errors.push("workflow supports at most 20 nodes");
  const ids = new Set<string>();
  for (const node of nodes) {
    if (!NODE_ID.test(node.id)) errors.push(`workflow node id ${JSON.stringify(node.id)} must match ${NODE_ID}`);
    if (ids.has(node.id)) errors.push(`duplicate workflow node id: ${node.id}`);
    ids.add(node.id);
  }
  for (const node of nodes) {
    const dependencies = node.dependsOn ?? [];
    if (new Set(dependencies).size !== dependencies.length) errors.push(`workflow node ${node.id} has duplicate dependencies`);
    for (const dependency of dependencies) {
      if (dependency === node.id) errors.push(`workflow node ${node.id} cannot depend on itself`);
      else if (!ids.has(dependency)) errors.push(`workflow node ${node.id} depends on unknown node ${dependency}`);
    }
  }
  const remaining = new Map(nodes.map((node) => [node.id, new Set(node.dependsOn ?? [])]));
  while (remaining.size > 0) {
    const ready = [...remaining].filter(([, dependencies]) => dependencies.size === 0).map(([id]) => id);
    if (ready.length === 0) {
      errors.push(`workflow contains a dependency cycle: ${[...remaining.keys()].join(", ")}`);
      break;
    }
    for (const id of ready) remaining.delete(id);
    for (const dependencies of remaining.values()) for (const id of ready) dependencies.delete(id);
  }
  return errors;
}

export function createWorkflowRecord(input: {
  workflowId: string;
  index: number;
  objective: string;
  background: boolean;
  nodes: WorkflowNodeSpec[];
}): WorkflowRecord {
  let settle!: () => void;
  return {
    workflowId: input.workflowId,
    index: input.index,
    objective: input.objective,
    status: "running",
    background: input.background,
    createdAt: Date.now(),
    nodes: new Map(input.nodes.map((spec) => [spec.id, { spec, status: "pending" }])),
    controller: new AbortController(),
    settled: new Promise<void>((resolve) => { settle = resolve; }),
    settle,
  };
}

const dependencyFailed = (node: WorkflowNodeRecord, records: ReadonlyMap<string, WorkflowNodeRecord>): boolean =>
  (node.spec.dependsOn ?? []).some((id) => {
    const status = records.get(id)?.status;
    return status === "failed" || status === "interrupted" || status === "skipped";
  });

const dependenciesSettled = (node: WorkflowNodeRecord, records: ReadonlyMap<string, WorkflowNodeRecord>): boolean =>
  (node.spec.dependsOn ?? []).every((id) => {
    const status = records.get(id)?.status;
    return status !== "pending" && status !== "running";
  });

export async function executeWorkflow(
  record: WorkflowRecord,
  deps: {
    canStart(): boolean;
    runNode(node: WorkflowNodeRecord, upstream: WorkflowNodeRecord[], signal: AbortSignal): Promise<WorkflowNodeResult>;
    onChange?(): void;
  },
): Promise<void> {
  const running = new Map<string, Promise<void>>();
  const update = () => deps.onChange?.();

  const start = (node: WorkflowNodeRecord): void => {
    node.status = "running";
    node.startedAt = Date.now();
    update();
    const upstream = (node.spec.dependsOn ?? []).map((id) => record.nodes.get(id)!).filter(Boolean);
    const task = deps.runNode(node, upstream, record.controller.signal).then((result) => {
      node.result = result;
      node.status = result.status;
      if (result.error) node.error = result.error;
    }, (error) => {
      node.status = record.controller.signal.aborted ? "interrupted" : "failed";
      node.error = error instanceof Error ? error.message : String(error);
    }).finally(() => {
      node.finishedAt = Date.now();
      running.delete(node.spec.id);
      update();
    });
    running.set(node.spec.id, task);
  };

  try {
    while ([...record.nodes.values()].some((node) => node.status === "pending" || node.status === "running")) {
      if (record.controller.signal.aborted) {
        for (const node of record.nodes.values()) {
          if (node.status === "pending") {
            node.status = "skipped";
            node.error = "Workflow interrupted before this node started";
          }
        }
        if (running.size > 0) await Promise.allSettled(running.values());
        break;
      }

      for (const node of record.nodes.values()) {
        if (node.status !== "pending" || !dependenciesSettled(node, record.nodes)) continue;
        if (dependencyFailed(node, record.nodes) && node.spec.runOnDependencyFailure !== true) {
          node.status = "skipped";
          node.error = "A dependency did not complete successfully";
          update();
        }
      }

      let started = false;
      for (const node of record.nodes.values()) {
        if (node.status !== "pending" || !dependenciesSettled(node, record.nodes) || !deps.canStart()) continue;
        start(node);
        started = true;
      }
      if (running.size > 0) {
        await Promise.race([
          ...running.values(),
          new Promise<void>((resolve) => setTimeout(resolve, 50)),
        ]);
      } else if (!started && [...record.nodes.values()].some((node) => node.status === "pending")) {
        await new Promise((resolve) => setTimeout(resolve, 50));
      }
    }
  } finally {
    record.finishedAt = Date.now();
    const statuses = [...record.nodes.values()].map((node) => node.status);
    record.status = record.controller.signal.aborted || statuses.includes("interrupted")
      ? "interrupted"
      : statuses.some((status) => status === "failed" || status === "skipped")
        ? "failed"
        : "completed";
    record.settle();
    update();
  }
}

export function workflowSnapshot(record: WorkflowRecord) {
  const boundedHandoff = (handoff: ModelSubagentHandoff) => ({
    ...(handoff.jobId ? { jobId: boundText(handoff.jobId, { maxCharacters: 100, maxLines: 1 }) } : {}),
    ...(handoff.ref ? { ref: boundText(handoff.ref, { maxCharacters: 24, maxLines: 1 }) } : {}),
    agent: boundText(handoff.agent, { maxCharacters: 80, maxLines: 1 }),
    status: handoff.status,
    summary: boundText(handoff.summary, { maxCharacters: 300, maxLines: 8 }),
    ...(handoff.changes ? { changes: boundText(handoff.changes, { maxCharacters: 100, maxLines: 4 }) } : {}),
    ...(handoff.evidence ? { evidence: boundText(handoff.evidence, { maxCharacters: 100, maxLines: 4 }) } : {}),
    ...(handoff.validation ? { validation: boundText(handoff.validation, { maxCharacters: 100, maxLines: 4 }) } : {}),
    ...(handoff.risks ? { risks: boundText(handoff.risks, { maxCharacters: 100, maxLines: 4 }) } : {}),
    ...(handoff.elapsedMs === undefined ? {} : { elapsedMs: handoff.elapsedMs }),
    transcript: {
      ...(handoff.transcript.sessionId ? { sessionId: boundText(handoff.transcript.sessionId, { maxCharacters: 200, maxLines: 1 }) } : {}),
      ...(handoff.transcript.sessionPath ? { sessionPath: boundText(handoff.transcript.sessionPath, { maxCharacters: 300, maxLines: 1 }) } : {}),
    },
  });
  return {
    workflowId: record.workflowId,
    ref: `W#${record.index}`,
    objective: boundText(record.objective, { maxCharacters: 1_500, maxLines: 20 }),
    status: record.status,
    background: record.background,
    elapsedMs: (record.finishedAt ?? Date.now()) - record.createdAt,
    nodes: [...record.nodes.values()].map((node) => ({
      id: node.spec.id,
      agent: node.spec.agent,
      objective: boundText(node.spec.objective, { maxCharacters: 400, maxLines: 8 }),
      dependsOn: node.spec.dependsOn ?? [],
      status: node.status,
      ...(node.result?.ref || node.runtimeRef ? { ref: node.result?.ref ?? node.runtimeRef } : {}),
      ...(node.result?.handoff ? { handoff: boundedHandoff(node.result.handoff) } : {}),
      ...(node.error ? { error: boundText(node.error, { maxCharacters: 500, maxLines: 8 }) } : {}),
      ...(node.startedAt === undefined ? {} : { elapsedMs: (node.finishedAt ?? Date.now()) - node.startedAt }),
    })),
  };
}
