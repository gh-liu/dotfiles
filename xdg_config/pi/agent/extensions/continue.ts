import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function buildContinuationPrompt(
  sessionFile: string | undefined,
  compactionEntryId: string,
): string {
  const sessionSource =
    sessionFile === undefined
      ? "This session is ephemeral, so no persisted session file is available."
      : [
        `The persisted session JSONL is ${JSON.stringify(sessionFile)}.`,
        "Inspect it directly with the read and bash tools.",
        "Do not launch a nested Pi process or open the session with `pi --session`.",
      ].join(" ");

  return `Resume the existing task now; do not wait for another user prompt.

${sessionSource}
Compaction entry ID: ${JSON.stringify(compactionEntryId)}.

Recovery procedure:
1. Start at the compaction entry and follow parentId links backward to reconstruct the active branch. Inspect the entries immediately before compaction first, then inspect older entries only when needed. Do not treat JSONL append order as conversation order because it may contain abandoned branches.
2. Recover the original goal and constraints, completed and in-progress work, decisions, changed files, commands/tests already run, blockers, and the intended next step.
3. Reconcile that history with the compaction summary and current worktree. The worktree is authoritative for file state; the session history is authoritative for user intent.
4. Briefly state the recovered context, then immediately execute the next unfinished step using the available tools. Do not stop at a recap.

Only ask the user to repeat context if the session data is genuinely unavailable or ambiguous. If no work remains, verify the result and report it.`;
}

/** Automatically resumes work after every successful Pi compaction. */
export default function continueAfterCompaction(pi: ExtensionAPI): void {
  const pendingTimers = new Set<ReturnType<typeof setTimeout>>();

  pi.on("session_compact", (event, ctx) => {
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
