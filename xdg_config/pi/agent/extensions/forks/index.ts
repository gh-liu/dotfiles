import { access } from "node:fs/promises";
import { setTimeout } from "node:timers/promises";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function forks(pi: ExtensionAPI): void {
  if (process.env.HERDR_ENV !== "1") return;

  pi.on("session_start", async (event, ctx) => {
    if (event.reason !== "fork" || ctx.mode !== "tui") return;
    const previous = event.previousSessionFile;
    if (!previous || !process.env.HERDR_PANE_ID) return;

    async function herdr(...args: string[]) {
      const shellDeadline = Date.now() + 5_000;
      for (;;) {
        const result = await pi.exec(process.env.HERDR_BIN_PATH || "herdr", args, { timeout: 40_000 });
        if (!result.killed && result.code === 0) return JSON.parse(result.stdout).result;
        let code: string | undefined;
        try { code = JSON.parse(result.stderr).error?.code; } catch { /* Not a structured server error. */ }
        // Tab creation can return before shell initialization finishes. Only this
        // explicit pre-launch rejection is safe to retry, never a timeout.
        if (!result.killed && code === "agent_pane_busy" && args[0] === "agent" && args[1] === "start" && Date.now() < shellDeadline) {
          await setTimeout(100);
          continue;
        }
        throw new Error(result.stderr.trim() || `herdr ${args.slice(0, 2).join(" ")} failed`);
      }
    }

    try {
      await access(previous);
      // Inherited tab IDs become stale after a move; resolve the caller live.
      const { pane: current } = await herdr("pane", "current", "--current");
      const { root_pane: restored } = await herdr(
        "tab", "create", "--workspace", current.workspace_id, "--cwd", ctx.cwd, "--label", "Restoring Pi", "--no-focus",
      );
      // agent start waits for interactive readiness, not just input admission.
      await herdr(
        "agent", "start", `pi-restore-${process.pid}-${Date.now().toString(36)}`, "--kind", "pi",
        "--pane", restored.pane_id, "--timeout", "30000", "--", "--session", previous,
      );
      const { tabs } = await herdr("tab", "list", "--workspace", current.workspace_id);
      const original = tabs.find((tab: { tab_id: string }) => tab.tab_id === current.tab_id);
      const originalLabel = original?.label?.trim();
      // Herdr's generated numeric label can differ from its stable tab number.
      const base = originalLabel && !/^\d+$/.test(originalLabel)
        ? originalLabel : ctx.sessionManager.getSessionName()?.trim() || "Pi";
      const stem = `${base} · fork`;
      const labels = new Set(tabs.map((tab: { label: string }) => tab.label));
      let label = stem;
      for (let suffix = 2; labels.has(label); suffix++) label = `${stem} ${suffix}`;
      // Keep the current layout intact during startup. Moving the ready pane
      // closes its temporary tab; only these two moves expose a brief split.
      const { move_result: restoredMove } = await herdr(
        "pane", "move", restored.pane_id, "--tab", current.tab_id, "--target-pane", current.pane_id, "--split", "right", "--no-focus",
      );
      if (!restoredMove.changed) throw new Error(`Restored pane was not moved: ${restoredMove.reason || "unknown reason"}`);
      const { move_result: moved } = await herdr("pane", "move", current.pane_id, "--new-tab", "--label", label, "--focus");
      if (!moved.changed) throw new Error(`Pane was not moved: ${moved.reason || "unknown reason"}`);
    } catch (error) {
      // Never close a pane on failure: startup/move may have succeeded despite
      // a timeout, and both sessions must remain recoverable.
      ctx.ui.notify(
        `Herdr fork layout failed; the forked session is still active. Any restored pane was left intact. ${error instanceof Error ? error.message : String(error)}`,
        "warning",
      );
    }
  });
}
