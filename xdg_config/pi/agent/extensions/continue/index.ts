// Automatically resumes the active task after Pi compacts the session context.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export function buildContinuationPrompt(
  sessionFile: string | undefined,
  compactionEntryId: string,
): string {
  const fallback = sessionFile === undefined
    ? "This session is ephemeral: no persisted JSONL is available. Continue from the summary and worktree; ask the user only if a decision-critical detail is genuinely unavailable or ambiguous."
    : `Only if a decision-critical detail is missing, contradictory, or ambiguous, inspect ${JSON.stringify(sessionFile)} with read/bash. Start at compaction entry ${JSON.stringify(compactionEntryId)} and follow parentId links backward; never infer the active branch from JSONL append order. Do not launch nested Pi or use \`pi --session\`. Ask the user only if the needed context remains genuinely unavailable or ambiguous.`;

  return `Resume the existing task immediately; do not wait for another user prompt.

Use Pi's compaction summary and the current worktree as the primary sources. From them recover the goal, constraints, progress, decisions, and next unfinished step. The worktree is authoritative for file state.

${fallback}

Execute the next unfinished step with the available tools; do not stop at a recap. If no work remains, verify the result and report it.`;
}

/** Automatically resumes work after every successful Pi compaction. */
export default function continueAfterCompaction(pi: ExtensionAPI): void {
  const pendingTimers = new Set<ReturnType<typeof setTimeout>>();

  pi.on("session_compact", (event, ctx) => {
    // Pi retries overflow compactions itself when willRetry is true. Queuing an
    // additional follow-up here would duplicate the recovery turn.
    if (event.willRetry) return;

    const prompt = buildContinuationPrompt(
      ctx.sessionManager.getSessionFile(),
      event.compactionEntry.id,
    );

    // Let manual compaction finish reconnecting the runtime before starting a
    // new turn. Follow-up delivery also handles automatic compaction recovery.
    const timer = setTimeout(() => {
      pendingTimers.delete(timer);
      pi.sendUserMessage(prompt, { deliverAs: "followUp" });
    }, 0);

    pendingTimers.add(timer);
  });

  pi.on("session_shutdown", () => {
    for (const timer of pendingTimers) clearTimeout(timer);
    pendingTimers.clear();
  });
}
