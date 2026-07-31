import {
  type ExtensionAPI,
  type ExtensionContext,
  getAgentDir,
  SettingsManager,
  type Theme,
} from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

type Activity = "ready" | "working";

interface StatusSnapshot {
  provider?: string;
  model?: string;
  thinking?: string;
  input: number;
  output: number;
  cacheHit?: number;
  cost: number;
  usageAvailable: boolean;
  costAvailable: boolean;
  subscription: boolean;
  contextPercent?: number;
  contextWindow: number;
  autoCompact: boolean;
}

interface StatusItem {
  id: string;
  text: string;
  zone: "left" | "right";
  dropRank: number;
  required?: boolean;
}

const NORD = {
  blue: [129, 161, 193], // nord9
  purple: [180, 142, 173], // nord15
  cyan: [136, 192, 208], // nord8
  amber: [235, 203, 139], // nord13
  red: [191, 97, 106], // nord11
  primary: [216, 222, 233], // nord4
  muted: [82, 90, 108], // nord3.5
} as const;

function paint(theme: Theme, color: keyof typeof NORD, text: string): string {
  if ("NO_COLOR" in process.env) {
    const fallback =
      color === "red"
        ? "error"
        : color === "amber"
          ? "warning"
          : color === "muted"
            ? "muted"
            : "text";
    return theme.fg(fallback, text);
  }
  const [red, green, blue] = NORD[color];
  return `\u001b[38;2;${red};${green};${blue}m${text}\u001b[39m`;
}

function formatTokens(value: number): string {
  const safe = Number.isFinite(value) ? Math.max(0, value) : 0;
  if (safe < 1_000) return String(safe);
  if (safe < 10_000) return `${(safe / 1_000).toFixed(1)}k`;
  if (safe < 1_000_000) return `${Math.round(safe / 1_000)}k`;
  if (safe < 10_000_000) return `${(safe / 1_000_000).toFixed(1)}M`;
  return `${Math.round(safe / 1_000_000)}M`;
}

function readSnapshot(pi: ExtensionAPI, ctx: ExtensionContext): StatusSnapshot {
  let input = 0;
  let output = 0;
  let cost = 0;
  let cacheHit: number | undefined;
  let usageAvailable = false;
  let costAvailable = false;

  for (const entry of ctx.sessionManager.getEntries()) {
    const usage =
      entry.type === "message" && entry.message.role === "assistant"
        ? entry.message.usage
        : entry.type === "message" && entry.message.role === "toolResult"
          ? entry.message.usage
          : (entry.type === "branch_summary" || entry.type === "compaction") && entry.usage
            ? entry.usage
            : undefined;
    if (!usage) continue;
    usageAvailable = true;
    input += Number.isFinite(usage.input) ? usage.input : 0;
    output += Number.isFinite(usage.output) ? usage.output : 0;
    if (Number.isFinite(usage.cost?.total)) {
      cost += usage.cost.total;
      costAvailable = true;
    }
    if (entry.type === "message" && entry.message.role === "assistant") {
      const prompt = usage.input + usage.cacheRead + usage.cacheWrite;
      cacheHit = prompt > 0 ? (usage.cacheRead / prompt) * 100 : undefined;
    }
  }

  const context = ctx.getContextUsage();
  const settings = SettingsManager.create(ctx.cwd, getAgentDir(), {
    projectTrusted: ctx.isProjectTrusted(),
  });
  return {
    provider: ctx.model?.provider,
    model: ctx.model?.id,
    thinking: pi.getThinkingLevel(),
    input,
    output,
    cacheHit,
    cost,
    usageAvailable,
    costAvailable,
    subscription: ctx.model ? ctx.modelRegistry.isUsingOAuth(ctx.model) : false,
    contextPercent: context?.percent ?? undefined,
    contextWindow: context?.contextWindow ?? ctx.model?.contextWindow ?? 0,
    autoCompact: settings.getCompactionEnabled(),
  };
}

function renderStatusLine(
  theme: Theme,
  width: number,
  activity: Activity,
  snapshot: StatusSnapshot,
  branch: string | null,
): string {
  if (width <= 0) return "";
  const contextColor =
    snapshot.contextPercent !== undefined && snapshot.contextPercent >= 90
      ? "red"
      : snapshot.contextPercent !== undefined && snapshot.contextPercent >= 70
        ? "amber"
        : "blue";
  const contextValue = `${snapshot.contextPercent === undefined ? "?" : `${snapshot.contextPercent.toFixed(1)}%`
    }${snapshot.contextWindow > 0 ? `/${formatTokens(snapshot.contextWindow)}` : ""}${snapshot.autoCompact ? " (auto)" : ""
    }`;
  const metric = (label: string, value: string, color: keyof typeof NORD) =>
    `${paint(theme, "muted", label)} ${paint(theme, color, value)}`;
  const items: StatusItem[] = [
    {
      id: "activity",
      zone: "left",
      text: paint(
        theme,
        activity === "ready" ? "blue" : "amber",
        theme.bold(`● ${activity.toUpperCase()}`),
      ),
      dropRank: Number.POSITIVE_INFINITY,
      required: true,
    },
    ...(snapshot.model
      ? [
        {
          id: "model",
          zone: "left" as const,
          text: `${paint(theme, "primary", snapshot.model)}${snapshot.provider ? paint(theme, "muted", `(${snapshot.provider})`) : ""
            }`,
          dropRank: 30,
        },
      ]
      : []),
    ...(snapshot.thinking
      ? [
        {
          id: "thinking",
          zone: "left" as const,
          text: paint(theme, "muted", snapshot.thinking),
          dropRank: 10,
        },
      ]
      : []),
    ...(branch
      ? [
        {
          id: "branch",
          zone: "left" as const,
          text: paint(theme, "primary", branch),
          dropRank: 10,
        },
      ]
      : []),
    {
      id: "input",
      zone: "right",
      text: metric("in", snapshot.usageAvailable ? formatTokens(snapshot.input) : "—", "blue"),
      dropRank: 40,
    },
    {
      id: "output",
      zone: "right",
      text: metric("out", snapshot.usageAvailable ? formatTokens(snapshot.output) : "—", "purple"),
      dropRank: 40,
    },
    {
      id: "cache",
      zone: "right",
      text: metric(
        "cache",
        snapshot.cacheHit === undefined ? "—" : `${Math.round(snapshot.cacheHit)}%`,
        "cyan",
      ),
      dropRank: 50,
    },
    {
      id: "cost",
      zone: "right",
      text: `${paint(
        theme,
        "amber",
        snapshot.costAvailable ? `$${snapshot.cost.toFixed(3)}` : "$—",
      )}${snapshot.subscription ? paint(theme, "muted", " (sub)") : ""}`,
      dropRank: 20,
    },
    {
      id: "context",
      zone: "right",
      text: metric("ctx", contextValue, contextColor),
      dropRank: Number.POSITIVE_INFINITY,
      required: true,
    },
  ];

  const active = [...items];
  const renderZone = (zone: StatusItem["zone"], separator: string) =>
    active
      .filter((item) => item.zone === zone)
      .map((item) => item.text)
      .join(separator);
  const left = () => renderZone("left", " · ");
  const right = () => renderZone("right", "  ");
  const measured = () => visibleWidth(left()) + visibleWidth(right()) + (left() && right() ? 2 : 0);

  for (const item of items
    .filter((item) => !item.required)
    .sort((a, b) => a.dropRank - b.dropRank)) {
    if (measured() <= width) break;
    const index = active.findIndex((candidate) => candidate.id === item.id);
    if (index >= 0) active.splice(index, 1);
  }

  const leftText = left();
  const rightText = right();
  const gap = width - visibleWidth(leftText) - visibleWidth(rightText);
  const line =
    leftText && rightText && gap >= 2
      ? `${leftText}${" ".repeat(gap)}${rightText}`
      : [leftText, rightText].filter(Boolean).join("  ");
  return truncateToWidth(line, width, "");
}

export default function status(pi: ExtensionAPI) {
  let activity: Activity = "ready";
  let currentSessionManager: ExtensionContext["sessionManager"] | undefined;
  let snapshot: StatusSnapshot | undefined;
  let requestRender = () => { };

  const isCurrentSession = (ctx: ExtensionContext) =>
    ctx.sessionManager === currentSessionManager;

  const refresh = (ctx: ExtensionContext) => {
    snapshot = readSnapshot(pi, ctx);
    requestRender();
  };

  pi.on("session_start", (_event, ctx) => {
    currentSessionManager = ctx.sessionManager;
    activity = ctx.isIdle() ? "ready" : "working";
    snapshot = readSnapshot(pi, ctx);
    if (ctx.mode !== "tui") return;

    ctx.ui.setWorkingVisible(false);
    ctx.ui.setFooter((tui, theme, footerData) => {
      let disposed = false;
      requestRender = () => {
        if (!disposed && isCurrentSession(ctx)) tui.requestRender();
      };
      const unsubscribe = footerData.onBranchChange(requestRender);
      return {
        render(width: number) {
          return [
            renderStatusLine(
              theme,
              width,
              activity,
              snapshot ?? readSnapshot(pi, ctx),
              footerData.getGitBranch(),
            ),
          ];
        },
        invalidate() { },
        dispose() {
          if (disposed) return;
          disposed = true;
          unsubscribe();
          if (isCurrentSession(ctx)) requestRender = () => { };
        },
      };
    });
  });

  pi.on("agent_start", (_event, ctx) => {
    if (!isCurrentSession(ctx)) return;
    activity = "working";
    requestRender();
  });

  pi.on("agent_settled", (_event, ctx) => {
    if (!isCurrentSession(ctx) || !ctx.isIdle()) return;
    activity = "ready";
    refresh(ctx);
  });

  pi.on("turn_end", (_event, ctx) => {
    if (isCurrentSession(ctx)) refresh(ctx);
  });
  pi.on("model_select", (_event, ctx) => {
    if (isCurrentSession(ctx)) refresh(ctx);
  });
  pi.on("thinking_level_select", (_event, ctx) => {
    if (isCurrentSession(ctx)) refresh(ctx);
  });
  pi.on("session_compact", (_event, ctx) => {
    if (isCurrentSession(ctx)) refresh(ctx);
  });

  pi.on("session_shutdown", (_event, ctx) => {
    if (!isCurrentSession(ctx)) return;
    ctx.ui.setFooter(undefined);
    currentSessionManager = undefined;
    snapshot = undefined;
    requestRender = () => { };
  });
}
