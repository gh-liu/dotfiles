const MAX_HANDOFF_CHARACTERS = 16_000;
const MAX_HANDOFF_LINES = 400;
const TRUNCATION_MARKER = "\n[truncated]";

export function redact(text: string, credentialValues: readonly string[]): string {
  let result = text;
  const secrets = [...new Set(credentialValues.filter(Boolean))]
    .sort((left, right) => right.length - left.length);
  for (const secret of secrets) result = result.split(secret).join("[REDACTED]");

  result = result
    .replace(/\b(sessionPath|transcriptPath)\s*[:=]\s*\S+/giu, "$1=[REDACTED]")
    .replace(/\b(processId|operationId|runId|sessionId|toolCallId)\s*[:=]\s*[^\s,;]+/giu, "$1=[REDACTED]");
  return result;
}

export function bound(text: string): string {
  const allLines = text.split(/\r?\n/u);
  let output = allLines.slice(0, MAX_HANDOFF_LINES).join("\n");
  const truncatedByLines = allLines.length > MAX_HANDOFF_LINES;
  if (output.length > MAX_HANDOFF_CHARACTERS - TRUNCATION_MARKER.length) {
    output = output.slice(0, MAX_HANDOFF_CHARACTERS - TRUNCATION_MARKER.length);
    return `${output}${TRUNCATION_MARKER}`;
  }
  return truncatedByLines ? `${output.slice(0, MAX_HANDOFF_CHARACTERS - TRUNCATION_MARKER.length)}${TRUNCATION_MARKER}` : output;
}

export function safeText(value: unknown, credentials: readonly string[]): string {
  const text = value instanceof Error ? value.message : String(value);
  return bound(redact(text, credentials));
}
