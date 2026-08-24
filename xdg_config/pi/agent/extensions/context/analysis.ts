const BUILTIN_TOOL_NAMES = new Set([
  "read",
  "write",
  "edit",
  "bash",
  "grep",
  "find",
  "ls",
  "exec",
  "todo",
  "ask",
]);

export const DEFAULT_COMPACTION_RESERVE_TOKENS = 16_384;

export interface ToolLike {
  name: string;
  description?: string;
  parameters?: unknown;
  promptGuidelines?: string[];
  sourceInfo?: { source?: string; path?: string };
}

export interface ContextFileLike {
  path: string;
  content: string;
}

export interface SkillLike {
  name: string;
  description?: string;
  filePath?: string;
  path?: string;
  disableModelInvocation?: boolean;
}

export function estimateTokens(text: string): number {
  return Math.ceil(text.length / 4);
}

export function safeStringify(value: unknown): string {
  const seen = new WeakSet<object>();
  try {
    return JSON.stringify(value, (_key, item: unknown) => {
      if (typeof item === "bigint") return item.toString();
      if (item && typeof item === "object") {
        if (seen.has(item)) return "[Circular]";
        seen.add(item);
      }
      return item;
    }) ?? "";
  } catch {
    return String(value);
  }
}

export function estimateValueTokens(value: unknown): number {
  return estimateTokens(typeof value === "string" ? value : safeStringify(value));
}

export function getCompactionReserveTokens(contextWindow: number): number {
  return Math.min(DEFAULT_COMPACTION_RESERVE_TOKENS, Math.max(0, contextWindow));
}

export function getBarSegments(usedTokens: number, contextWindow: number, reserveTokens: number, width: number) {
  if (width <= 0 || contextWindow <= 0) return { used: 0, free: 0, reserve: 0 };
  const used = Math.min(
    width,
    usedTokens > 0 ? Math.max(1, Math.round((Math.min(usedTokens, contextWindow) / contextWindow) * width)) : 0,
  );
  const reserveTarget = reserveTokens > 0
    ? Math.max(1, Math.round((Math.min(reserveTokens, contextWindow) / contextWindow) * width))
    : 0;
  const reserve = Math.min(reserveTarget, width - used);
  return { used, free: width - used - reserve, reserve };
}

export function getScrollMetrics(contentHeight: number, viewportHeight: number, requestedOffset: number) {
  const content = Math.max(0, Math.floor(contentHeight));
  const viewport = Math.max(1, Math.floor(viewportHeight));
  const maxOffset = Math.max(0, content - viewport);
  const offset = Math.max(0, Math.min(maxOffset, Math.floor(requestedOffset)));
  const thumbSize = content > viewport ? Math.max(1, Math.floor(viewport * viewport / content)) : viewport;
  const thumbTravel = Math.max(0, viewport - thumbSize);
  const thumbStart = maxOffset > 0 ? Math.round(offset / maxOffset * thumbTravel) : 0;
  return { offset, maxOffset, thumbSize, thumbStart };
}

export function parseWheelDirection(data: string): -1 | 1 | undefined {
  const sgr = /^\x1b\[<(\d+);\d+;\d+[Mm]$/u.exec(data);
  if (sgr) {
    const button = Number.parseInt(sgr[1], 10);
    if ((button & 64) === 0) return undefined;
    const direction = button & 3;
    return direction === 0 ? -1 : direction === 1 ? 1 : undefined;
  }
  if (data.length === 6 && data.startsWith("\x1b[M")) {
    const button = data.charCodeAt(3) - 32;
    if ((button & 64) === 0) return undefined;
    const direction = button & 3;
    return direction === 0 ? -1 : direction === 1 ? 1 : undefined;
  }
  return undefined;
}

export function basename(path: string): string {
  const parts = path.split(/[\\/]/u);
  return parts.at(-1) || path;
}

export function classifyActiveTools(allTools: ToolLike[], activeToolNames: readonly string[]) {
  const active = new Set(activeToolNames);
  const systemTools: ToolLike[] = [];
  const extensionTools: ToolLike[] = [];
  for (const tool of allTools) {
    if (!active.has(tool.name)) continue;
    const source = tool.sourceInfo?.source ?? "";
    const path = tool.sourceInfo?.path ?? "";
    const systemOwned = source === "builtin"
      || source === "sdk"
      || BUILTIN_TOOL_NAMES.has(tool.name)
      || path.includes("pi-coding-agent")
      || path.includes("pi-ai")
      || path.startsWith("<builtin");
    (systemOwned ? systemTools : extensionTools).push(tool);
  }
  return { systemTools, extensionTools };
}

function estimateContent(content: unknown): number {
  if (typeof content === "string") return estimateTokens(content);
  if (!Array.isArray(content)) return estimateValueTokens(content);
  return content.reduce((total, part) => {
    if (!part || typeof part !== "object") return total + estimateValueTokens(part);
    const record = part as Record<string, unknown>;
    if (typeof record.text === "string") return total + estimateTokens(record.text);
    if (typeof record.thinking === "string") {
      return total + estimateTokens(record.thinking) + estimateValueTokens(record.thinkingSignature);
    }
    if (record.type === "image" || record.type === "image_url") return total + 256;
    return total + estimateValueTokens(record);
  }, 0);
}

export interface MessageBreakdown {
  total: number;
  byRole: Record<"user" | "assistant" | "toolResult" | "bashExecution" | "other", number>;
}

export function analyzeMessages(messages: readonly unknown[]): MessageBreakdown {
  const byRole: MessageBreakdown["byRole"] = {
    user: 0,
    assistant: 0,
    toolResult: 0,
    bashExecution: 0,
    other: 0,
  };
  for (const value of messages) {
    if (!value || typeof value !== "object") {
      byRole.other += estimateValueTokens(value);
      continue;
    }
    const message = value as Record<string, unknown>;
    const role = typeof message.role === "string" ? message.role : "other";
    let tokens: number;
    if (role === "bashExecution") {
      tokens = estimateValueTokens(message.command) + estimateValueTokens(message.output);
    } else if (role === "branchSummary" || role === "compactionSummary") {
      tokens = estimateValueTokens(message.summary);
    } else {
      tokens = estimateContent(message.content);
      if (role === "toolResult") tokens += estimateValueTokens(message.toolName);
    }
    const bucket = role === "user" || role === "assistant" || role === "toolResult" || role === "bashExecution"
      ? role
      : "other";
    byRole[bucket] += tokens;
  }
  return { total: Object.values(byRole).reduce((sum, value) => sum + value, 0), byRole };
}

export function attributeSystemPrompt(
  systemPrompt: string,
  contextFiles: readonly ContextFileLike[],
  skills: readonly SkillLike[],
) {
  const promptTotal = estimateTokens(systemPrompt);
  const memoryEstimate = contextFiles.reduce((sum, file) => {
    if (!systemPrompt.includes(file.path)) return sum;
    return sum + estimateTokens(file.content) + estimateTokens(file.path) + 12;
  }, 0);
  const skillsEstimate = skills.reduce((sum, skill) => {
    const location = skill.filePath ?? skill.path ?? "";
    if (skill.disableModelInvocation || !location || !systemPrompt.includes(location)) return sum;
    return sum + estimateTokens(skill.name) + estimateTokens(skill.description ?? "") + estimateTokens(location) + 20;
  }, 0);
  const attributed = memoryEstimate + skillsEstimate > promptTotal
    ? scaleTokenGroups({ memory: memoryEstimate, skills: skillsEstimate }, promptTotal)
    : { memory: memoryEstimate, skills: skillsEstimate };
  return {
    systemPromptRaw: promptTotal - attributed.memory - attributed.skills,
    memoryFilesRaw: attributed.memory,
    skillsRaw: attributed.skills,
  };
}

/** Scale estimates to the authoritative total while preserving an exact sum. */
export function scaleTokenGroups<T extends string>(values: Record<T, number>, total: number): Record<T, number> {
  const entries = Object.entries(values) as Array<[T, number]>;
  const rawTotal = entries.reduce((sum, [, value]) => sum + Math.max(0, value), 0);
  if (rawTotal === 0) {
    return Object.fromEntries(entries.map(([key], index) => [key, index === 0 ? total : 0])) as Record<T, number>;
  }
  const scaled = entries.map(([key, value]) => {
    const exact = Math.max(0, value) * total / rawTotal;
    return { key, value: Math.floor(exact), remainder: exact - Math.floor(exact) };
  });
  let remaining = total - scaled.reduce((sum, entry) => sum + entry.value, 0);
  scaled.sort((left, right) => right.remainder - left.remainder);
  for (let index = 0; index < scaled.length && remaining > 0; index += 1, remaining -= 1) {
    scaled[index].value += 1;
  }
  return Object.fromEntries(scaled.map(({ key, value }) => [key, value])) as Record<T, number>;
}
