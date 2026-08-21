import type { SubagentResult } from "./protocol.ts";

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

/** Serializes the parent-visible result envelope under a hard character budget. */
export function serializeSubagentResult(result: SubagentResult): string {
  const maxCharacters = 32_000;
  let low = 0;
  let high = Math.min(result.summary.length, maxCharacters);
  let best: string | undefined;
  while (low <= high) {
    const summaryLimit = Math.floor((low + high) / 2);
    const summary = summaryLimit === 0
      ? ""
      : boundText(result.summary, { maxCharacters: summaryLimit, maxLines: 400 });
    const serialized = JSON.stringify({ ...result, summary });
    if (serialized.length <= maxCharacters) {
      best = serialized;
      low = summaryLimit + 1;
    } else {
      high = summaryLimit - 1;
    }
  }
  if (best !== undefined) return best;
  throw new Error("Subagent result envelope exceeds the parent serialization limit");
}
