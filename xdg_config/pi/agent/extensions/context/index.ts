import {
  type ExtensionAPI,
  type ExtensionContext,
  sessionEntryToContextMessages,
} from "@earendil-works/pi-coding-agent";
import { Box, type Component, Container, matchesKey, Text, Spacer } from "@earendil-works/pi-tui";
import {
  calculateContextUsage,
  type ContextFileLike,
  type SkillLike,
  getBarSegments,
  getCompactionReserveTokens,
  getScrollMetrics,
  parseWheelDirection,
} from "./analysis.js";
import { Type } from "typebox";
import { formatTokens } from "./utils.js";

const MAX_DETAIL_ITEMS = 5;

function truncateLabel(label: string, width: number): string {
  if (label.length <= width) return label;
  return label.slice(0, width - 1) + "…";
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "context_usage",
    label: "Context usage",
    description: "Read-only bounded context usage as structured JSON: model, tokens, limit, percent, category estimates, and top details. Never returns prompt, session, or credential contents.",
    parameters: Type.Object({}),
    async execute(_toolCallId, _input, _signal, _onUpdate, ctx) {
      const usage = ctx.getContextUsage();
      if (
        !usage
        || usage.tokens === null
        || usage.tokens === undefined
        || usage.contextWindow === null
        || usage.contextWindow === undefined
        || usage.percent === null
        || usage.percent === undefined
      ) {
        return { content: [{ type: "text" as const, text: JSON.stringify({ error: "Context usage info not available." }) }], details: { error: true } };
      }
      const promptOptions = (ctx as ExtensionContext & { getSystemPromptOptions?: () => { contextFiles?: ContextFileLike[]; skills?: SkillLike[] } }).getSystemPromptOptions?.();
      const analysis = calculateContextUsage({
        systemPrompt: ctx.getSystemPrompt(),
        contextFiles: promptOptions?.contextFiles ?? [],
        skills: promptOptions?.skills ?? [],
        messages: ctx.sessionManager.buildContextEntries().flatMap(sessionEntryToContextMessages),
        allTools: pi.getAllTools(),
        activeToolNames: pi.getActiveTools(),
        totalActual: usage.tokens,
      });
      const result = {
        model: ctx.model?.id ?? ctx.model?.name ?? "unknown",
        tokens: usage.tokens,
        limit: usage.contextWindow,
        percent: usage.percent,
        categories: analysis.categories.map(({ label, value, details }) => ({ label, tokens: value, ...(details?.length ? { topDetails: details } : {}) })),
      };
      return { content: [{ type: "text" as const, text: JSON.stringify(result) }], details: result };
    },
  });

  pi.registerCommand("context", {
    description: "Show context usage visualization",
    handler: async (args, ctx) => {
      const showAll = args.trim() === "all";

      if (ctx.mode !== "tui") {
        ctx.ui.notify("The /context visualization requires TUI mode.", "warning");
        return;
      }

      const usage = ctx.getContextUsage();
      if (!usage) {
        ctx.ui.notify("Context usage info not available.", "warning");
        return;
      }

      const totalActual = usage.tokens;
      const limit = usage.contextWindow;
      const usagePercent = usage.percent;

      if (totalActual == null || limit == null || usagePercent == null) {
        ctx.ui.notify("Context usage info not available.", "warning");
        return;
      }

      const model = ctx.model;
      const modelName: string = model?.id ?? model?.name ?? "unknown";
      const headerModel = modelName && modelName !== "undefined" ? modelName : "unknown";

      const systemPrompt = ctx.getSystemPrompt();
      const sysPromptOptions = ctx.getSystemPromptOptions();
      const contextFiles = sysPromptOptions.contextFiles ?? [];
      const skills = sysPromptOptions.skills ?? [];
      const messages = ctx.sessionManager
        .buildContextEntries()
        .flatMap(sessionEntryToContextMessages);

      const { categories } = calculateContextUsage({
        systemPrompt,
        contextFiles,
        skills,
        messages,
        allTools: pi.getAllTools(),
        activeToolNames: pi.getActiveTools(),
        totalActual,
      });

      const bufferTokens = getCompactionReserveTokens(limit);
      const freeTokens = Math.max(0, limit - totalActual - bufferTokens);
      const overflowTokens = totalActual > limit ? totalActual - limit : 0;

      await ctx.ui.custom((tui, theme, kb, done) => {
        const ownsMouseTracking = tui.mode === "regular";
        if (ownsMouseTracking) tui.terminal.write("\x1b[?1000h\x1b[?1006h");
        let cachedWidth = 0;
        let cachedPanel: Component | null = null;
        let scrollOffset = 0;
        let viewportHeight = 1;
        let maxScrollOffset = 0;

        const makeContainer = (w: number) => {
          const contentWidth = Math.max(28, w - 6);
          const statusColor = overflowTokens > 0 ? "error" : usagePercent >= 80 ? "warning" : "accent";
          const barWidth = Math.max(20, Math.min(60, contentWidth));
          const bar = getBarSegments(totalActual, limit, bufferTokens, barWidth);
          const contextBar = theme.fg(statusColor as any, "█".repeat(bar.used))
            + theme.fg("borderMuted", "░".repeat(bar.free))
            + theme.fg("warning", "▒".repeat(bar.reserve));

          const c = new Container();
          c.addChild(new Text(theme.fg("accent", theme.bold(" Context")), 1, 0));
          c.addChild(new Text(`  ${theme.fg("muted", headerModel)}`, 1, 0));
          c.addChild(new Text(`  ${theme.fg("text", theme.bold(formatTokens(totalActual)))} ${theme.fg("dim", `of ${formatTokens(limit)}`)}  ${theme.fg(statusColor as any, theme.bold(`${usagePercent.toFixed(1)}% used`))}`, 1, 0));
          c.addChild(new Text(`  ${contextBar}`, 1, 0));
          c.addChild(new Text(`  ${theme.fg(statusColor as any, "█ used")}  ${theme.fg("borderMuted", "░ free")}  ${theme.fg("warning", "▒ reserve*")}`, 1, 0));
          if (w < 55) {
            c.addChild(new Text(`  ${theme.fg("text", formatTokens(freeTokens))} ${theme.fg("dim", "free before compaction")}`, 1, 0));
            c.addChild(new Text(`  ${theme.fg("warning", formatTokens(bufferTokens))} ${theme.fg("dim", "reserved")}`, 1, 0));
          } else {
            c.addChild(new Text(`  ${theme.fg("text", formatTokens(freeTokens))} ${theme.fg("dim", "free before compaction")}  ${theme.fg("dim", "·")}  ${theme.fg("warning", formatTokens(bufferTokens))} ${theme.fg("dim", "reserved")}`, 1, 0));
          }
          c.addChild(new Spacer(1));
          c.addChild(new Text(`  ${theme.fg("text", theme.bold("Breakdown"))} ${theme.fg("dim", "· share of used context")}`, 1, 0));

          const labelWidth = Math.max(12, Math.min(22, contentWidth - 18));
          const miniBarWidth = contentWidth >= 60 ? Math.min(18, contentWidth - labelWidth - 20) : 0;
          for (const category of categories) {
            const percentage = totalActual > 0 ? (category.value / totalActual) * 100 : 0;
            const filled = miniBarWidth > 0 ? Math.min(miniBarWidth, Math.round((percentage / 100) * miniBarWidth)) : 0;
            const miniBar = miniBarWidth > 0
              ? ` ${theme.fg(category.color as any, "━".repeat(filled))}${theme.fg("borderMuted", "─".repeat(miniBarWidth - filled))}`
              : "";
            const label = truncateLabel(category.label, labelWidth).padEnd(labelWidth);
            const tokens = formatTokens(category.value).padStart(7);
            const percent = `${percentage.toFixed(1)}%`.padStart(6);
            c.addChild(new Text(
              `  ${theme.fg(category.color as any, "●")} ${theme.fg("text", label)}${miniBar} ${theme.fg("accent", tokens)} ${theme.fg("dim", percent)}`,
              1,
              0,
            ));

            if (showAll && category.details && category.details.length > 0) {
              const visibleDetails = category.details.slice(0, MAX_DETAIL_ITEMS);
              for (const [index, detail] of visibleDetails.entries()) {
                const detailLabel = truncateLabel(detail.label, labelWidth - 2).padEnd(labelWidth - 2);
                const detailTokens = formatTokens(detail.tokens).padStart(7);
                const detailPct = `${(totalActual > 0 ? detail.tokens / totalActual * 100 : 0).toFixed(1)}%`.padStart(6);
                const detailGap = miniBarWidth > 0 ? " ".repeat(miniBarWidth + 1) : "";
                const connector = index === visibleDetails.length - 1 ? "└" : "├";
                c.addChild(new Text(
                  `  ${theme.fg("dim", connector)} ${theme.fg("muted", `  ${detailLabel}`)}${detailGap} ${theme.fg("muted", detailTokens)} ${theme.fg("dim", detailPct)}`,
                  1,
                  0,
                ));
              }
              if (category.details.length > MAX_DETAIL_ITEMS) {
                c.addChild(new Text(`    ${theme.fg("dim", `+${category.details.length - MAX_DETAIL_ITEMS} more`)}`, 1, 0));
              }
            }
          }

          const warnings: string[] = [];
          if (overflowTokens > 0) {
            warnings.push(theme.fg("error", theme.bold(`⚠ ${formatTokens(overflowTokens)} over limit`)) + theme.fg("warning", " · run /compact"));
          } else if (freeTokens === 0) {
            warnings.push(theme.fg("warning", "⚠ Compaction threshold reached · run /compact if needed"));
          } else if (usagePercent >= 90) {
            warnings.push(theme.fg("warning", `⚠ ${usagePercent.toFixed(1)}% used · consider /compact`));
          }

          if (warnings.length > 0) {
            c.addChild(new Spacer(1));
            for (const wline of warnings) {
              c.addChild(new Text(`  ${wline}`, 1, 0));
            }
          }

          c.addChild(new Spacer(1));
          c.addChild(new Text(`  ${theme.fg("dim", w < 55 ? "* Reserve estimate: Pi default 16k" : "* Reserve estimate uses Pi default 16k; custom value unavailable")}`, 1, 0));
          c.addChild(new Text(`  ${theme.fg("dim", showAll
            ? "Wheel/↑↓ scroll · PgUp/PgDn · Esc/q closes"
            : w < 55 ? "Wheel/↑↓ · Esc/q closes · /context all" : "Wheel/↑↓ scroll · Esc/q closes · /context all for details")}`, 1, 0));
          const body = new Box(1, 0, (line) => theme.bg("customMessageBg", line));
          body.addChild(c);
          return {
            render: (width: number) => {
              const innerWidth = Math.max(1, width - 2);
              const border = (text: string) => theme.fg("borderAccent", text);
              const maxBodyHeight = Math.max(3, Math.floor(tui.terminal.rows * 0.9) - 2);
              let bodyLines = body.render(innerWidth);
              const needsScroll = bodyLines.length > maxBodyHeight;
              if (needsScroll && innerWidth > 1) bodyLines = body.render(innerWidth - 1);
              viewportHeight = Math.min(bodyLines.length, maxBodyHeight);
              const scroll = getScrollMetrics(bodyLines.length, viewportHeight, scrollOffset);
              scrollOffset = scroll.offset;
              maxScrollOffset = scroll.maxOffset;
              const visibleLines = bodyLines.slice(scroll.offset, scroll.offset + viewportHeight);
              const renderedLines = needsScroll
                ? visibleLines.map((line, index) => {
                    const inThumb = index >= scroll.thumbStart && index < scroll.thumbStart + scroll.thumbSize;
                    const marker = theme.bg(
                      "customMessageBg",
                      theme.fg(inThumb ? "accent" : "borderMuted", inThumb ? "█" : "░"),
                    );
                    return `${line}${marker}`;
                  })
                : visibleLines;
              return [
                border(`┌${"─".repeat(innerWidth)}┐`),
                ...renderedLines.map((line) => `${border("│")}${line}${border("│")}`),
                border(`└${"─".repeat(innerWidth)}┘`),
              ];
            },
            invalidate: () => body.invalidate(),
          };
        };

        return {
          render: (w: number) => {
            if (!cachedPanel || w !== cachedWidth) {
              cachedWidth = w;
              cachedPanel = makeContainer(w);
            }
            return cachedPanel.render(w);
          },
          invalidate: () => {
            cachedPanel?.invalidate();
          },
          handleInput: (data: string) => {
            const wheelDirection = parseWheelDirection(data);
            if (wheelDirection !== undefined) {
              scrollOffset = Math.max(0, Math.min(maxScrollOffset, scrollOffset + wheelDirection * 3));
            } else if (kb.matches(data, "tui.select.up") || data === "k") {
              scrollOffset = Math.max(0, scrollOffset - 1);
            } else if (kb.matches(data, "tui.select.down") || data === "j") {
              scrollOffset = Math.min(maxScrollOffset, scrollOffset + 1);
            } else if (kb.matches(data, "tui.select.pageUp")) {
              scrollOffset = Math.max(0, scrollOffset - Math.max(1, viewportHeight - 2));
            } else if (kb.matches(data, "tui.select.pageDown")) {
              scrollOffset = Math.min(maxScrollOffset, scrollOffset + Math.max(1, viewportHeight - 2));
            } else if (matchesKey(data, "home")) {
              scrollOffset = 0;
            } else if (matchesKey(data, "end")) {
              scrollOffset = maxScrollOffset;
            } else if (kb.matches(data, "tui.select.cancel") || data === "q" || data === "\r" || data === "\n") {
              done(undefined);
              return;
            } else if (!showAll) {
              done(undefined);
              return;
            } else {
              return;
            }
            cachedPanel?.invalidate?.();
            tui.requestRender();
          },
          dispose: () => {
            if (ownsMouseTracking) tui.terminal.write("\x1b[?1006l\x1b[?1000l");
          },
        };
      }, {
        overlay: true,
        overlayOptions: { anchor: "center", margin: 1, maxHeight: "90%", width: 84 },
      });
    },
  });
}
