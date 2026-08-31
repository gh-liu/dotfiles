import type { SubagentResult } from "./protocol.ts";

export const SUBAGENT_HANDOFF_MAX_CHARACTERS = 16_000;

type ModelSubagentHandoffSource = Pick<SubagentResult, "agent" | "status" | "summary" | "transcript"> & {
  jobId?: string;
  ref?: string;
  elapsedMs?: number;
};

export interface ModelSubagentHandoff {
  jobId?: string;
  ref?: string;
  agent: string;
  status: SubagentResult["status"];
  summary: string;
  changes?: string;
  evidence?: string;
  validation?: string;
  risks?: string;
  elapsedMs?: number;
  transcript: SubagentResult["transcript"];
}

export function extractStructuredHandoff(text: string): Pick<ModelSubagentHandoff, "summary" | "changes" | "evidence" | "validation" | "risks"> {
  const sections = new Map<string, string>();
  const heading = /^#{1,3}\s+(summary|changes|evidence|validation|risks)\s*$/gim;
  const matches = [...text.matchAll(heading)];
  for (const [index, match] of matches.entries()) {
    const key = match[1]!.toLowerCase();
    const start = match.index! + match[0].length;
    const end = matches[index + 1]?.index ?? text.length;
    const value = text.slice(start, end).trim();
    if (value) sections.set(key, value);
  }
  if (sections.size === 0) return { summary: text };
  return {
    summary: sections.get("summary") ?? text,
    ...(sections.get("changes") ? { changes: sections.get("changes") } : {}),
    ...(sections.get("evidence") ? { evidence: sections.get("evidence") } : {}),
    ...(sections.get("validation") ? { validation: sections.get("validation") } : {}),
    ...(sections.get("risks") ? { risks: sections.get("risks") } : {}),
  };
}

interface TextLimits {
  maxCharacters: number;
  maxLines: number;
}

const TRUNCATION_MARKER = "[truncated]";

function validatePositiveLimit(value: number, name: string): void {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new Error(`${name} must be a positive integer`);
  }
}

export function redactSecrets(text: string, exactValues: string[] = []): string {
  const values = [...new Set(exactValues.filter((value) => value.length > 0))].sort(
    (left, right) => right.length - left.length,
  );
  const replaceExactValues = (part: string): string => {
    let result = "";
    let cursor = 0;
    while (cursor < part.length) {
      let nextIndex = -1;
      let nextValue = "";
      for (const value of values) {
        const index = part.indexOf(value, cursor);
        if (index !== -1 && (nextIndex === -1 || index < nextIndex)) {
          nextIndex = index;
          nextValue = value;
        }
      }
      if (nextIndex === -1) return result + part.slice(cursor);
      result += `${part.slice(cursor, nextIndex)}[REDACTED]`;
      cursor = nextIndex + nextValue.length;
    }
    return result;
  };
  const redacted = text
    .replace(/\[REDACTED:[^\]\r\n]+\]/g, "[REDACTED]")
    .split(/(\[REDACTED\])/g)
    .map((part) => (part === "[REDACTED]" ? part : replaceExactValues(part)))
    .join("");

  return redacted
    .replace(/\b(authorization\s*:\s*bearer)\s+\S+/gi, "$1 [REDACTED]")
    .replace(
      /(^|[^a-z0-9])(["']?(?:[a-z0-9]+[_-])*(?:api[_-]?key|token|secret|password)["']?\s*[:=]\s*)(["']?)(?!\[REDACTED\])([^"'\s,}\]]+)["']?/gi,
      "$1$2$3[REDACTED]$3",
    )
    .replace(/\b(?:sk-(?:proj-)?[a-z0-9_-]{16,}|gh[pousr]_[a-z0-9]{20,}|AIza[a-z0-9_-]{20,})\b/gi, "[REDACTED]");
}

export function boundText(text: string, limits: TextLimits, exactSecretValues: string[] = []): string {
  validatePositiveLimit(limits.maxCharacters, "maxCharacters");
  validatePositiveLimit(limits.maxLines, "maxLines");

  const redacted = redactSecrets(text, exactSecretValues);
  const lines = redacted.split("\n");
  if (lines.length <= limits.maxLines && redacted.length <= limits.maxCharacters) return redacted;
  if (limits.maxLines === 1 || limits.maxCharacters <= TRUNCATION_MARKER.length) {
    return TRUNCATION_MARKER.slice(0, limits.maxCharacters);
  }

  const prefixLimit = limits.maxCharacters - TRUNCATION_MARKER.length - 1;
  const prefix = lines
    .slice(0, limits.maxLines - 1)
    .join("\n")
    .slice(0, prefixLimit)
    .replace(/\n+$/g, "");
  return prefix === "" ? TRUNCATION_MARKER : `${prefix}\n${TRUNCATION_MARKER}`;
}

/** Projects authoritative details into the compact handoff needed by the parent model. */
export function modelSubagentHandoff(result: ModelSubagentHandoffSource): ModelSubagentHandoff {
  const extracted = extractStructuredHandoff(result.summary);
  return {
    ...(result.jobId === undefined ? {} : { jobId: result.jobId }),
    ...(result.ref === undefined ? {} : { ref: result.ref }),
    agent: result.agent,
    status: result.status,
    ...extracted,
    ...(result.elapsedMs === undefined ? {} : { elapsedMs: result.elapsedMs }),
    transcript: result.transcript,
  };
}

/** Serializes the model-facing handoff under a hard character budget. */
export function serializeSubagentResult(result: ModelSubagentHandoffSource): string {
  const handoff = modelSubagentHandoff(result);
  const fields = ["summary", "changes", "evidence", "validation", "risks"] as const;
  const bounded = { ...handoff };
  let serialized = JSON.stringify(bounded);
  while (serialized.length > SUBAGENT_HANDOFF_MAX_CHARACTERS) {
    const field = fields.reduce<(typeof fields)[number] | undefined>((longest, candidate) => {
      const value = bounded[candidate];
      if (!value) return longest;
      return !longest || value.length > (bounded[longest]?.length ?? 0) ? candidate : longest;
    }, undefined);
    if (!field) throw new Error("Subagent result envelope exceeds the parent serialization limit");
    const value = bounded[field]!;
    if (value.length <= 1) {
      delete bounded[field];
    } else {
      const next = boundText(value, {
        maxCharacters: Math.max(1, Math.floor(value.length / 2)),
        maxLines: 400,
      });
      if (next.length >= value.length) delete bounded[field];
      else bounded[field] = next;
    }
    serialized = JSON.stringify(bounded);
  }
  return serialized;
}
