type SubagentRenderArgs =
  | {
      action: "run"; agent: string; objective: string; background?: boolean; cwd?: string; deadlineMs?: number;
      model?: string; thinking?: string; scope?: string[]; constraints?: string[]; acceptance?: string[]; context?: string;
    }
  | { action: "get"; jobId?: string; waitMs?: number }
  | { action: "cancel"; jobId: string };

interface SubagentRenderState {
  spinnerFrame?: number;
  spinnerTimer?: ReturnType<typeof setInterval>;
  /** Immutable per-row runtime identity, learned only from authoritative result details. */
  runtimeIndex?: number;
  /** Session-local public alias learned from authoritative result details. */
  ref?: string;
  /** Effective model learned from authoritative progress/update details. */
  model?: string;
  /** Effective thinking level learned from authoritative progress/update details. */
  thinking?: string;
  /** Prevents the result-triggered repaint from recursively scheduling itself. */
  runtimeIndexInvalidateQueued?: boolean;
}

interface SubagentRenderResult {
  content: Array<{ type: string; text?: string }>;
  details?: unknown;
}

interface SubagentRenderContext {
  args: SubagentRenderArgs;
  isError: boolean;
  expanded?: boolean;
  state: SubagentRenderState;
  invalidate(): void;
}

function oneLine(text: string, maxCharacters = 160): string {
  const normalized = text.replace(/\s+/g, " ").trim();
  return normalized.length <= maxCharacters
    ? normalized
    : `${normalized.slice(0, maxCharacters - 1)}…`;
}

function formatCountdown(ms: number): string {
  // Seconds-only keeps the live view consistent with the title's `· 240s` deadline hint.
  return `${Math.max(0, Math.ceil(ms / 1000))}s`;
}

function boundedLines(text: string, maxCharacters: number, maxLines: number): string[] {
  const lines = text.replace(/\r\n?/g, "\n").trim().split("\n");
  const selected = lines.slice(0, maxLines);
  let bounded = selected.join("\n");
  const truncated = lines.length > maxLines || bounded.length > maxCharacters;
  if (bounded.length > maxCharacters) bounded = bounded.slice(0, maxCharacters).replace(/\s+$/g, "");
  const result = bounded.split("\n");
  if (truncated) result[result.length - 1] = `${result[result.length - 1]}…`;
  return result;
}

function collapseHome(value: string): string {
  const home = process.env.HOME;
  if (!home || home === "/") return value;
  return value.startsWith(`${home}/`) ? `~${value.slice(home.length)}` : value;
}

/** One-line human summary of the work order: strip labels/markdown, first meaningful text. */
function taskTitle(task: string | undefined, maxCharacters = 80): string {
  if (!task) return "";
  const firstLine = task
    .split("\n")
    .map((line) => line.trim())
    .find((line) => line.length > 0 && !line.startsWith("#")) ?? "";
  return oneLine(firstLine.replace(/^outcome\s*[:：]\s*/i, ""), maxCharacters);
}

function positiveSafeRuntimeIndex(value: unknown): number | undefined {
  return typeof value === "number" && Number.isSafeInteger(value) && value > 0 ? value : undefined;
}

function publicRef(value: string | undefined): string | undefined {
  if (!value) return undefined;
  const match = /^(?:#)?([1-9]\d*)$/.exec(value);
  return match ? `#${match[1]}` : undefined;
}

export { boundedLines, collapseHome, formatCountdown, oneLine, positiveSafeRuntimeIndex, publicRef, taskTitle };
export type { SubagentRenderArgs, SubagentRenderContext, SubagentRenderResult, SubagentRenderState };
