/**
 * Renders a live footer with agent activity, model, token usage, cost, and context status.
 *
 * Pi event                                          Footer activity
 * ------------------------------------------------  ----------------
 * session_start (idle), agent_settled (idle, unless ERROR)   READY
 * session_start (active), before_agent_start, agent_start    WAITING
 * content phase end or assistant message_end (non-error)     WAITING
 * thinking_start, thinking_delta                    THINKING
 * text_start, text_delta                            STREAMING
 * toolcall_start, toolcall_delta                    TOOL CALLING
 * tool_execution_start, tool_execution_update       RUNNING TOOLS
 * last tool_execution_end                           WAITING
 * session_before_compact                            COMPACTING
 * ui_prompt_start (overlay over base activity)      INPUT NEEDED
 * assistant provider error / compaction failure     ERROR
 *
 * WAITING is the conservative fallback while the agent is active but Pi exposes no
 * current thinking, text streaming, or tool execution activity.
 */

import { watch, type FSWatcher } from "node:fs";
import { homedir } from "node:os";
import {
  type ExtensionAPI,
  type ExtensionContext,
  CustomEditor,
  getAgentDir,
  SettingsManager,
  type Theme,
} from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

type Activity =
  | "ready"
  | "waiting"
  | "thinking"
  | "streaming"
  | "tool_calling"
  | "running_tools"
  | "compacting"
  | "awaiting_user"
  | "error";

type BaseActivity = Exclude<Activity, "awaiting_user">;

const ACTIVE_SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"] as const;
const THINKING_FRAMES = ["∼", "≈", "≋", "≈"] as const;
const TOOL_SPINNER_FRAMES = ["›", "»", "≫", "»"] as const;
// LCM of 10 (active) and 4 (thinking/tool) so every spinner cycles without skipping frames.
const SPINNER_CYCLE = 20;
const MAX_BRANCH_WIDTH = 32;
const MAX_DIRECTORY_WIDTH = 32;
const MAX_SESSION_NAME_WIDTH = 32;
const GRAPHEME_SEGMENTER = new Intl.Segmenter(undefined, { granularity: "grapheme" });

function takeGraphemes(value: string, count: number): string {
  return Array.from(GRAPHEME_SEGMENTER.segment(value), ({ segment }) => segment)
    .slice(0, count)
    .join("");
}

function abbreviateDirectoryName(name: string, initials: number): string {
  const abbreviated = !name.startsWith(".") || name === "." || name === ".."
    ? takeGraphemes(name, initials)
    // A lone dot is not useful, so hidden directories always retain one name initial.
    : `.${takeGraphemes(name.slice(1), Math.max(1, initials - 1))}`;
  return abbreviated === name ? name : `${abbreviated}…`;
}

export function formatDirectory(cwd: string, maxWidth = MAX_DIRECTORY_WIDTH): string {
  if (maxWidth <= 0) return "";
  const home = homedir();
  const display = cwd === home ? "~" : cwd.startsWith(`${home}/`) ? `~${cwd.slice(home.length)}` : cwd;
  if (visibleWidth(display) <= maxWidth) return display;

  const parts = display.split("/");
  if (parts.length <= 2) return truncateToWidth(display, maxWidth, "…");

  const abbreviated = (initials: number) => parts
    .map((part, index) => index > 0 && index < parts.length - 1
      ? abbreviateDirectoryName(part, initials)
      : part)
    .join("/");
  for (const initials of [2, 1]) {
    const candidate = abbreviated(initials);
    if (visibleWidth(candidate) <= maxWidth) return candidate;
  }

  const prefix = parts[0] ? `${parts[0]}/…/` : "/…/";
  const leafWidth = maxWidth - visibleWidth(prefix);
  if (leafWidth <= 0) return truncateToWidth(prefix, maxWidth, "");
  return `${prefix}${truncateToWidth(parts.at(-1) ?? "", leafWidth, "…")}`;
}

interface StatusSnapshot {
  provider?: string;
  model?: string;
  sessionName?: string;
  thinking?: Parameters<Theme["getThinkingBorderColor"]>[0];
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
  green: [163, 190, 140], // nord14
  primary: [216, 222, 233], // nord4
  muted: [82, 90, 108], // nord3.5
} as const;

const ACTIVITY_DISPLAY = {
  ready: { color: "blue", label: "● READY", spinner: [] },
  waiting: { color: "amber", label: "WAITING", spinner: ACTIVE_SPINNER_FRAMES },
  thinking: { color: "purple", label: "THINKING", spinner: THINKING_FRAMES },
  streaming: { color: "amber", label: "STREAMING", spinner: ACTIVE_SPINNER_FRAMES },
  tool_calling: { color: "cyan", label: "TOOL CALLING", spinner: TOOL_SPINNER_FRAMES },
  running_tools: { color: "cyan", label: "RUNNING TOOLS", spinner: TOOL_SPINNER_FRAMES },
  compacting: { color: "purple", label: "COMPACTING", spinner: THINKING_FRAMES },
  awaiting_user: { color: "green", label: "◇ INPUT NEEDED", spinner: [] },
  error: { color: "red", label: "◌ ERROR", spinner: [] },
} as const satisfies Record<
  Activity,
  { color: keyof typeof NORD; label: string; spinner: readonly string[] }
>;

function paint(theme: Theme, color: keyof typeof NORD, text: string): string {
  if (process.env.NO_COLOR) {
    const fallback =
      color === "red"
        ? "error"
        : color === "amber"
          ? "warning"
          : color === "muted"
            ? "muted"
            : color === "green"
              ? "success"
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

function isUsingSubscription(ctx: ExtensionContext): boolean {
  if (!ctx.model) return false;
  // Kimi Coding is subscription-backed despite using API-key authentication.
  if (ctx.model.provider === "kimi-coding") return true;
  return ctx.modelRegistry.isUsingOAuth(ctx.model)
    && ctx.modelRegistry.getProvider(ctx.model.provider)?.auth.oauth?.isSubscription === true;
}

function readSnapshot(pi: ExtensionAPI, ctx: ExtensionContext): StatusSnapshot {
  let input = 0;
  let output = 0;
  let cost = 0;
  let cacheHit: number | undefined;
  let usageAvailable = false;
  let costAvailable = false;

  for (const entry of ctx.sessionManager.getEntries()) {
    // Non-message work (for example cache warming) is billed too, regardless of kind.
    const usage =
      entry.type === "usage"
        ? entry.usage
        : entry.type === "message" && entry.message.role === "assistant"
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
    // Cache hit describes the latest assistant prompt, not background work or totals.
    if (entry.type === "message" && entry.message.role === "assistant") {
      const promptInput = Number.isFinite(usage.input) ? Math.max(0, usage.input) : 0;
      const cacheRead = Number.isFinite(usage.cacheRead) ? Math.max(0, usage.cacheRead) : 0;
      const cacheWrite = Number.isFinite(usage.cacheWrite) ? Math.max(0, usage.cacheWrite) : 0;
      const prompt = promptInput + cacheRead + cacheWrite;
      cacheHit = prompt > 0 ? (cacheRead / prompt) * 100 : undefined;
    }
  }

  const context = ctx.getContextUsage();
  const settings = SettingsManager.create(ctx.cwd, getAgentDir(), {
    projectTrusted: ctx.isProjectTrusted(),
  });
  return {
    provider: ctx.model?.provider,
    model: ctx.model?.id,
    sessionName: pi.getSessionName(),
    thinking: pi.getThinkingLevel(),
    input,
    output,
    cacheHit,
    cost,
    usageAvailable,
    costAvailable,
    subscription: isUsingSubscription(ctx),
    contextPercent: context?.percent ?? undefined,
    contextWindow: context?.contextWindow ?? ctx.model?.contextWindow ?? 0,
    autoCompact: settings.getCompactionEnabled(),
  };
}

function renderEditorBorder(
  editorTheme: { borderColor: (text: string) => string },
  footerTheme: Theme | undefined,
  width: number,
  snapshot: StatusSnapshot | undefined,
  position: "top" | "bottom",
  hiddenLineCount = 0,
): string {
  if (width <= 0) return "";
  const thinking = snapshot?.thinking;
  const borderColor = footerTheme
    ? footerTheme.getThinkingBorderColor(thinking ?? "off")
    : editorTheme.borderColor;
  const fillBorder = (fillWidth: number, direction: "↑" | "↓"): string => {
    if (fillWidth <= 0) return "";
    if (hiddenLineCount <= 0) return borderColor("─".repeat(fillWidth));
    const label = ` ${direction} ${hiddenLineCount} more `;
    const labelWidth = visibleWidth(label);
    if (labelWidth + 2 <= fillWidth) {
      const left = Math.floor((fillWidth - labelWidth) / 2);
      const right = fillWidth - left - labelWidth;
      return borderColor(`${"─".repeat(left)}${label}${"─".repeat(right)}`);
    }
    if (labelWidth <= fillWidth) {
      return borderColor(`${label}${"─".repeat(fillWidth - labelWidth)}`);
    }
    return borderColor("─".repeat(fillWidth));
  };
  if (position === "bottom") {
    return fillBorder(width, "↓");
  }
  const semantic = (color: keyof typeof NORD, text: string) =>
    footerTheme ? paint(footerTheme, color, text) : text;
  const providerText = snapshot?.provider ? semantic("muted", `(${snapshot.provider})`) : "";
  const modelText = snapshot?.model ? semantic("primary", snapshot.model) : "";
  const thinkingText = thinking
    ? footerTheme ? footerTheme.getThinkingBorderColor(thinking)(thinking) : thinking
    : "";
  const metadataText = [thinkingText, [modelText, providerText].filter(Boolean).join("")]
    .filter(Boolean)
    .join(" • ");
  if (!metadataText) {
    return fillBorder(width, "↑");
  }
  const rawSemantic = truncateToWidth(` ${metadataText} `, width, "");
  const semanticText = footerTheme ? rawSemantic : editorTheme.borderColor(rawSemantic);
  const leftWidth = Math.max(0, width - visibleWidth(semanticText));
  return `${fillBorder(leftWidth, "↑")}${semanticText}`;
}

function renderStatusLine(
  theme: Theme,
  width: number,
  activity: Activity,
  spinnerFrame: number,
  snapshot: StatusSnapshot,
  branch: string | null,
  cwd: string,
): string {
  width = Math.max(0, width - 1);
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
  const display = ACTIVITY_DISPLAY[activity];
  const activityText = display.spinner.length > 0
    ? `${display.spinner[spinnerFrame % display.spinner.length]} ${display.label}`
    : display.label;
  const items: StatusItem[] = [
    {
      id: "activity",
      zone: "left",
      text: paint(theme, display.color, ` ${activityText} `),
      dropRank: 30,
    },
    {
      id: "directory",
      zone: "left",
      text: paint(theme, "muted", truncateToWidth(formatDirectory(cwd), MAX_DIRECTORY_WIDTH, "…")),
      dropRank: 10,
    },
    ...(branch
      ? [
        {
          id: "branch",
          zone: "left" as const,
          text: paint(theme, "green", truncateToWidth(branch, MAX_BRANCH_WIDTH, "…")),
          dropRank: 20,
        },
      ]
      : []),
    ...(snapshot.sessionName
      ? [
        {
          id: "session",
          zone: "left" as const,
          text: paint(theme, "primary", truncateToWidth(snapshot.sessionName, MAX_SESSION_NAME_WIDTH, "…")),
          dropRank: 15,
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
  let baseActivity: BaseActivity = "ready";
  let currentFooterTheme: Theme | undefined;
  let currentSessionManager: ExtensionContext["sessionManager"] | undefined;
  let snapshot: StatusSnapshot | undefined;
  let requestRender = () => { };
  let spinnerFrame = 0;
  let spinnerTimer: ReturnType<typeof setInterval> | undefined;
  let settingsWatcher: FSWatcher | undefined;
  let uiPromptActive = false;
  let agentRunActive = false;
  let compacting = false;
  const executingToolCalls = new Set<string>();

  const currentActivity = (): Activity => (uiPromptActive ? "awaiting_user" : baseActivity);

  const stopSpinner = () => {
    if (spinnerTimer !== undefined) clearInterval(spinnerTimer);
    spinnerTimer = undefined;
    spinnerFrame = 0;
  };

  const startSpinner = () => {
    if (spinnerTimer !== undefined) return;
    spinnerTimer = setInterval(() => {
      spinnerFrame = (spinnerFrame + 1) % SPINNER_CYCLE;
      requestRender();
    }, 80);
  };

  const syncActivity = () => {
    if (ACTIVITY_DISPLAY[currentActivity()].spinner.length > 0) startSpinner();
    else stopSpinner();
    requestRender();
  };

  const setBaseActivity = (next: BaseActivity) => {
    baseActivity = next;
    syncActivity();
  };

  const stopSettingsWatcher = () => {
    settingsWatcher?.close();
    settingsWatcher = undefined;
  };

  const isCurrentSession = (ctx: ExtensionContext) => ctx.sessionManager === currentSessionManager;

  const refresh = (ctx: ExtensionContext) => {
    snapshot = readSnapshot(pi, ctx);
    requestRender();
  };

  const activityAfterCompaction = (
    ctx: ExtensionContext,
    event: { reason?: string; willRetry?: boolean },
  ): BaseActivity => {
    if (event.willRetry) return "waiting";
    if (event.reason === "manual") return "ready";
    return agentRunActive || !ctx.isIdle() ? "waiting" : "ready";
  };

  pi.on("session_start", (_event, ctx) => {
    stopSpinner();
    stopSettingsWatcher();
    executingToolCalls.clear();
    uiPromptActive = false;
    compacting = false;
    if (ctx.mode !== "tui") {
      agentRunActive = false;
      baseActivity = "ready";
      currentSessionManager = undefined;
      snapshot = undefined;
      return;
    }
    currentSessionManager = ctx.sessionManager;
    agentRunActive = !ctx.isIdle();
    baseActivity = ctx.isIdle() ? "ready" : "waiting";
    snapshot = readSnapshot(pi, ctx);

    ctx.ui.setWorkingVisible(false);
    ctx.ui.setEditorComponent?.((tui, theme, keybindings) =>
      new (class extends CustomEditor {
        protected override renderTopBorder(width: number, hiddenLineCount: number): string {
          return renderEditorBorder(
            theme,
            currentFooterTheme,
            width,
            snapshot,
            "top",
            hiddenLineCount,
          );
        }

        protected override renderBottomBorder(width: number, hiddenLineCount: number): string {
          return renderEditorBorder(
            theme,
            currentFooterTheme,
            width,
            snapshot,
            "bottom",
            hiddenLineCount,
          );
        }
      })(tui, theme, keybindings),
    );
    const cwd = ctx.cwd;
    ctx.ui.setFooter((tui, theme, footerData) => {
      currentFooterTheme = theme;
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
              currentActivity(),
              spinnerFrame,
              snapshot ?? readSnapshot(pi, ctx),
              footerData.getGitBranch(),
              cwd,
            ),
          ];
        },
        invalidate() { },
        dispose() {
          if (disposed) return;
          disposed = true;
          unsubscribe();
          if (currentFooterTheme === theme) currentFooterTheme = undefined;
          if (isCurrentSession(ctx)) {
            stopSpinner();
            stopSettingsWatcher();
            requestRender = () => { };
          }
        },
      };
    });
    try {
      settingsWatcher = watch(getAgentDir(), { persistent: false }, (_eventType, filename) => {
        if ((filename == null || filename === "settings.json") && isCurrentSession(ctx)) {
          refresh(ctx);
        }
      });
      settingsWatcher.on?.("error", stopSettingsWatcher);
    } catch {
      settingsWatcher = undefined;
    }
    if (ACTIVITY_DISPLAY[currentActivity()].spinner.length > 0) startSpinner();
  });

  pi.on("before_agent_start", (_event, ctx) => {
    if (!isCurrentSession(ctx) || ctx.mode !== "tui") return;
    agentRunActive = true;
    compacting = false;
    executingToolCalls.clear();
    setBaseActivity("waiting");
  });

  pi.on("agent_start", (_event, ctx) => {
    if (!isCurrentSession(ctx) || ctx.mode !== "tui") return;
    agentRunActive = true;
    compacting = false;
    executingToolCalls.clear();
    setBaseActivity("waiting");
  });

  pi.on("ui_prompt_start", (_event, ctx) => {
    if (!isCurrentSession(ctx) || ctx.mode !== "tui") return;
    uiPromptActive = true;
    syncActivity();
  });

  pi.on("ui_prompt_end", (_event, ctx) => {
    if (!isCurrentSession(ctx) || ctx.mode !== "tui") return;
    uiPromptActive = false;
    syncActivity();
  });

  pi.on("message_update", (event, ctx) => {
    if (!isCurrentSession(ctx) || ctx.mode !== "tui") return;
    switch (event.assistantMessageEvent.type) {
      case "start":
      case "thinking_end":
      case "text_end":
      case "toolcall_end":
      case "done":
        setBaseActivity("waiting");
        break;
      case "thinking_start":
      case "thinking_delta":
        setBaseActivity("thinking");
        break;
      case "text_start":
      case "text_delta":
        setBaseActivity("streaming");
        break;
      case "toolcall_start":
      case "toolcall_delta":
        setBaseActivity("tool_calling");
        break;
      case "error":
        setBaseActivity(event.assistantMessageEvent.reason === "error" ? "error" : "waiting");
        break;
    }
  });

  pi.on("message_end", (event, ctx) => {
    if (!isCurrentSession(ctx) || ctx.mode !== "tui" || event.message.role !== "assistant") return;
    setBaseActivity(
      event.message.stopReason === "error"
        ? "error"
        : executingToolCalls.size > 0
          ? "running_tools"
          : "waiting",
    );
  });

  pi.on("tool_execution_start", (event, ctx) => {
    if (!isCurrentSession(ctx) || ctx.mode !== "tui") return;
    executingToolCalls.add(event.toolCallId);
    setBaseActivity("running_tools");
  });

  pi.on("tool_execution_update", (event, ctx) => {
    if (!isCurrentSession(ctx) || ctx.mode !== "tui") return;
    executingToolCalls.add(event.toolCallId);
    setBaseActivity("running_tools");
  });

  pi.on("tool_execution_end", (event, ctx) => {
    if (!isCurrentSession(ctx) || ctx.mode !== "tui") return;
    executingToolCalls.delete(event.toolCallId);
    setBaseActivity(executingToolCalls.size > 0 ? "running_tools" : "waiting");
  });

  pi.on("agent_settled", (_event, ctx) => {
    if (!isCurrentSession(ctx) || ctx.mode !== "tui") return;
    agentRunActive = false;
    executingToolCalls.clear();
    snapshot = readSnapshot(pi, ctx);
    if (ctx.isIdle() && baseActivity !== "error") setBaseActivity("ready");
    else requestRender();
  });

  pi.on("turn_end", (_event, ctx) => {
    if (isCurrentSession(ctx) && ctx.mode === "tui") refresh(ctx);
  });
  pi.on("model_select", (_event, ctx) => {
    if (isCurrentSession(ctx) && ctx.mode === "tui") refresh(ctx);
  });
  pi.on("thinking_level_select", (_event, ctx) => {
    if (isCurrentSession(ctx) && ctx.mode === "tui") refresh(ctx);
  });
  pi.on("session_info_changed", (_event, ctx) => {
    if (isCurrentSession(ctx) && ctx.mode === "tui") refresh(ctx);
  });
  pi.on("session_tree", (_event, ctx) => {
    if (!isCurrentSession(ctx) || ctx.mode !== "tui") return;
    snapshot = readSnapshot(pi, ctx);
    if (baseActivity === "error" && ctx.isIdle()) setBaseActivity("ready");
    else requestRender();
  });
  pi.on("session_before_compact", (_event, ctx) => {
    if (!isCurrentSession(ctx) || ctx.mode !== "tui") return;
    compacting = true;
    setBaseActivity("compacting");
  });
  pi.on("session_compact", (event, ctx) => {
    if (!isCurrentSession(ctx) || ctx.mode !== "tui") return;
    compacting = false;
    snapshot = readSnapshot(pi, ctx);
    setBaseActivity(activityAfterCompaction(ctx, event));
  });
  pi.on("session_compact_failed", (event, ctx) => {
    if (!isCurrentSession(ctx) || ctx.mode !== "tui") return;
    const wasCompacting = compacting;
    compacting = false;
    snapshot = readSnapshot(pi, ctx);
    if (event.aborted) {
      setBaseActivity(activityAfterCompaction(ctx, event));
    } else if (wasCompacting) {
      setBaseActivity("error");
    } else {
      requestRender();
    }
  });

  pi.on("session_shutdown", (_event, ctx) => {
    if (!isCurrentSession(ctx)) return;
    ctx.ui.setFooter(undefined);
    ctx.ui.setEditorComponent?.(undefined);
    ctx.ui.setWorkingVisible?.(true);
    stopSpinner();
    stopSettingsWatcher();
    executingToolCalls.clear();
    uiPromptActive = false;
    agentRunActive = false;
    compacting = false;
    baseActivity = "ready";
    currentSessionManager = undefined;
    currentFooterTheme = undefined;
    snapshot = undefined;
    requestRender = () => { };
  });
}
