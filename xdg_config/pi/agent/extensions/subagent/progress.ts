import type { SubagentActivityPhase, SubagentProgress, SubagentTimelineEntry, SubagentToolProgressItem } from "./protocol.ts";
import { boundText } from "./output.ts";

export interface NormalizedProgress {
  summary: string;
  recentActivity: string[];
  timeline?: SubagentTimelineEntry[];
  tools?: {
    earlierCount: number;
    history: SubagentToolProgressItem[];
    active: SubagentToolProgressItem[];
  };
  phase?: SubagentActivityPhase;
  /** Concurrent active-tool count for live affordance. */
  activeCount?: number;
}

/** Single bounded projection for progress summaries, timelines, tools, and phases. */
export function normalizeProgress(value: string | SubagentProgress): NormalizedProgress {
  const progress: SubagentProgress = typeof value === "string" ? { summary: value } : value;
  const summary = boundText(progress.summary, { maxCharacters: 240, maxLines: 1 });
  const recentActivity = (progress.timeline ?? [])
    .slice(-8)
    .flatMap((entry) => entry.kind === "thinking"
      ? ["✓ Thinking"]
      : [`${entry.status === "failed" ? "✗" : "✓"} ${boundText(entry.summary, { maxCharacters: 160, maxLines: 1 })}`]);
  return {
    summary,
    recentActivity,
    ...(progress.timeline ? { timeline: progress.timeline.map((entry) => ({ ...entry })) } : {}),
    ...(progress.phase ? { phase: { ...progress.phase } } : {}),
    ...(progress.tools ? {
      tools: {
        earlierCount: progress.tools.earlierCount,
        history: progress.tools.history.map((entry) => ({ ...entry })),
        active: progress.tools.active.map((entry) => ({ ...entry })),
      },
    } : {}),
    ...(progress.tools ? { activeCount: progress.tools.active.length } : {}),
  };
}
