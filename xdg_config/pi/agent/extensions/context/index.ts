import {
  type ExtensionAPI,
  sessionEntryToContextMessages,
} from "@earendil-works/pi-coding-agent";
import { Box, type Component, Container, matchesKey, Text, Spacer } from "@earendil-works/pi-tui";
import {
  analyzeMessages,
  attributeSystemPrompt,
  basename,
  classifyActiveTools,
  estimateTokens,
  estimateValueTokens,
  getBarSegments,
  getCompactionReserveTokens,
  getScrollMetrics,
  scaleTokenGroups,
} from "./analysis.js";
import { formatTokens } from "./utils.js";

const MAX_DETAIL_ITEMS = 5;

const ROLE_LABELS: Record<string, string> = {
  user: "User messages",
  assistant: "Assistant replies",
  toolResult: "Tool results",
  bashExecution: "Bash",
  other: "Other",
};

function displayRole(role: string): string {
  return ROLE_LABELS[role] ?? role;
}

function truncateLabel(label: string, width: number): string {
  if (label.length <= width) return label;
  return label.slice(0, width - 1) + "…";
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("context", {
    description: "Show context usage visualization",
    handler: async (args, ctx) => {
      const showAll = args.trim() === "all";

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

      const { systemTools, extensionTools } = classifyActiveTools(
        pi.getAllTools(),
        pi.getActiveTools(),
      );
      const promptParts = attributeSystemPrompt(systemPrompt, contextFiles, skills);
      const systemToolsRaw = systemTools.length > 0 ? estimateValueTokens(systemTools) : 0;
      const extensionToolsRaw = extensionTools.length > 0 ? estimateValueTokens(extensionTools) : 0;
      const messageAnalysis = analyzeMessages(messages);

      const tokenGroups = scaleTokenGroups({
        systemPrompt: promptParts.systemPromptRaw,
        memoryFiles: promptParts.memoryFilesRaw,
        skills: promptParts.skillsRaw,
        systemTools: systemToolsRaw,
        extensionTools: extensionToolsRaw,
        messages: messageAnalysis.total,
      }, totalActual);
      const systemPromptTokens = tokenGroups.systemPrompt;
      const memoryTokens = tokenGroups.memoryFiles;
      const skillsTokens = tokenGroups.skills;
      const systemToolsTokens = tokenGroups.systemTools;
      const extensionToolsTokens = tokenGroups.extensionTools;
      const messagesTokens = tokenGroups.messages;
      const messagesByRole = scaleTokenGroups(messageAnalysis.byRole, messagesTokens);
      const totalRaw = promptParts.systemPromptRaw + promptParts.memoryFilesRaw + promptParts.skillsRaw
        + systemToolsRaw + extensionToolsRaw + messageAnalysis.total;
      const ratio = totalRaw > 0 ? totalActual / totalRaw : 1;

      // Sorted by token count so the heaviest items surface first
      const systemToolsDetail = systemTools
        .map((t) => ({
          name: t.name,
          tokens: Math.round(estimateValueTokens(t) * ratio),
        }))
        .sort((a, b) => b.tokens - a.tokens);
      const extensionToolsDetail = extensionTools
        .map((t) => ({
          name: t.name,
          tokens: Math.round(estimateValueTokens(t) * ratio),
        }))
        .sort((a, b) => b.tokens - a.tokens);
      const memoryFilesDetail = contextFiles
        .filter((file) => systemPrompt.includes(file.path))
        .map((f) => ({
          path: f.path,
          base: basename(f.path),
          tokens: Math.round((estimateTokens(f.content) + estimateTokens(f.path) + 12) * ratio),
        }))
        .sort((a, b) => b.tokens - a.tokens);
      const skillsDetail = skills
        .filter((skill) => !skill.disableModelInvocation && systemPrompt.includes(skill.filePath))
        .map((skill) => ({
          label: skill.name,
          tokens: Math.round((
            estimateTokens(skill.name)
            + estimateTokens(skill.description)
            + estimateTokens(skill.filePath)
            + 20
          ) * ratio),
        }))
        .sort((a, b) => b.tokens - a.tokens);

      const bufferTokens = getCompactionReserveTokens(limit);
      const freeTokens = Math.max(0, limit - totalActual - bufferTokens);
      const overflowTokens = totalActual > limit ? totalActual - limit : 0;

      type Detail = { label: string; tokens: number };
      type Category = {
        label: string;
        value: number;
        color: string;
        details?: Detail[];
      };

      const categories: Category[] = [
        { label: "System prompt", value: systemPromptTokens, color: "muted" },
        {
          label: "System tools",
          value: systemToolsTokens,
          color: "success",
          details: systemToolsDetail.map((item) => ({ label: item.name, tokens: item.tokens })),
        },
        {
          label: "Extension tools",
          value: extensionToolsTokens,
          color: "accent",
          details: extensionToolsDetail.map((item) => ({ label: item.name, tokens: item.tokens })),
        },
        {
          label: "Memory files",
          value: memoryTokens,
          color: "dim",
          details: memoryFilesDetail.map((item) => ({ label: item.base, tokens: item.tokens })),
        },
        {
          label: "Skills",
          value: skillsTokens,
          color: "dim",
          details: skillsDetail.map((item) => ({ label: item.label, tokens: item.tokens })),
        },
        {
          label: "Messages",
          value: messagesTokens,
          color: "accent",
          details: Object.entries(messagesByRole)
            .filter(([, tokens]) => tokens > 0)
            .map(([role, tokens]) => ({ label: displayRole(role), tokens }))
            .sort((left, right) => right.tokens - left.tokens),
        },
      ]
        .filter((category) => category.value > 0)
        .sort((left, right) => right.value - left.value);

      await ctx.ui.custom((tui, theme, kb, done) => {
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
          c.addChild(new Text(`  ${theme.fg("dim", showAll ? "↑↓/PgUp/PgDn scroll · Esc/q closes" : w < 55 ? "/context all · any key closes" : "/context all for details · any key closes")}`, 1, 0));
          const body = new Box(1, 0, (line) => theme.bg("customMessageBg", line));
          body.addChild(c);
          return {
            render: (width: number) => {
              const innerWidth = Math.max(1, width - 2);
              const border = (text: string) => theme.fg("borderAccent", text);
              const maxBodyHeight = showAll
                ? Math.max(3, Math.floor(tui.terminal.rows * 0.9) - 2)
                : Number.POSITIVE_INFINITY;
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
            if (!showAll) {
              done(undefined);
              return;
            }
            if (kb.matches(data, "tui.select.up") || data === "k") {
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
            } else {
              return;
            }
            cachedPanel?.invalidate?.();
            tui.requestRender();
          },
        };
      }, {
        overlay: true,
        overlayOptions: { anchor: "center", margin: 1, maxHeight: "90%", width: 84 },
      });
    },
  });
}
