import {
  type ExtensionAPI,
  DynamicBorder,
  sessionEntryToContextMessages,
} from "@earendil-works/pi-coding-agent";
import { Container, Text, Spacer } from "@earendil-works/pi-tui";
import {
  analyzeMessages,
  attributeSystemPrompt,
  basename,
  classifyActiveTools,
  estimateTokens,
  estimateValueTokens,
  getCompactionReserveTokens,
  getGridDimensions,
  scaleTokenGroups,
} from "./analysis.js";
import { formatTokens } from "./utils.js";

// Four-symbol grid: used (<70% / >=70%), buffer, empty
const SYMBOL_USED_LOW = "⛀";
const SYMBOL_USED_HIGH = "⛁";
const SYMBOL_BUFFER = "⛝";
const SYMBOL_EMPTY = "⛶";

const MAX_DETAIL_ITEMS = 5;
// Only expand per-item details for categories that actually matter (>= 0.5% of window)
const DETAIL_MIN_PCT = 0.5;

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

      type Cat = {
        label: string;
        value: number;
        color: string;
        isFree?: boolean;
        isBuffer?: boolean;
      };

      const categories: Cat[] = [
        { label: "System prompt", value: systemPromptTokens, color: "muted" },
        { label: "System tools", value: systemToolsTokens, color: "success" },
        { label: "Extension tools", value: extensionToolsTokens, color: "accent" },
        { label: "Memory files", value: memoryTokens, color: "dim" },
        { label: "Skills", value: skillsTokens, color: "dim" },
        { label: "Messages", value: messagesTokens, color: "accent" },
        { label: "Free space", value: freeTokens, color: "borderMuted", isFree: true },
        { label: "Compact reserve*", value: bufferTokens, color: "warning", isBuffer: true },
      ];

      const visibleCategories = categories.filter((c) => {
        if (c.label === "Extension tools" && c.value === 0 && !showAll) return false;
        return true;
      });

      const usedCategories = categories.filter((c) => !c.isFree && !c.isBuffer);

      await ctx.ui.custom((tui, theme, kb, done) => {
        // Precompute outside makeContainer but theme-dependent grid uses theme.fg
        const buildContent = (renderWidth: number) => {
          const { w: gridWidth, h: gridHeight, total: totalBlocks } = getGridDimensions(limit, renderWidth);

          const blocks: Array<{ color: string; symbol: string }> = [];

          for (const cat of usedCategories) {
            if (cat.value <= 0) continue;
            let count = Math.round((cat.value / limit) * totalBlocks);
            if (count === 0 && cat.value > 0) count = 1;
            for (let i = 0; i < count && blocks.length < totalBlocks; i++) {
              const sym = usagePercent >= 70 ? SYMBOL_USED_HIGH : SYMBOL_USED_LOW;
              blocks.push({ color: cat.color, symbol: sym });
            }
          }

          let bufferBlocks = Math.round((bufferTokens / limit) * totalBlocks);
          if (bufferBlocks === 0 && bufferTokens > 0) bufferBlocks = 1;
          const remainingAfterUsed = totalBlocks - blocks.length;
          bufferBlocks = Math.min(bufferBlocks, Math.max(0, remainingAfterUsed));
          for (let i = 0; i < bufferBlocks; i++) {
            blocks.push({ color: "warning", symbol: SYMBOL_BUFFER });
          }
          while (blocks.length < totalBlocks) {
            blocks.push({ color: "borderMuted", symbol: SYMBOL_EMPTY });
          }
          if (overflowTokens > 0) {
            for (let i = 0; i < blocks.length; i++) {
              blocks[i] = { color: "error", symbol: SYMBOL_USED_HIGH };
            }
          }

          const gridLines: string[] = [];
          for (let r = 0; r < gridHeight; r++) {
            let rowStr = "";
            for (let c = 0; c < gridWidth; c++) {
              const b = blocks[r * gridWidth + c];
              if (!b) continue;
              rowStr += theme.fg(b.color as any, b.symbol + " ");
            }
            gridLines.push(rowStr.trimEnd());
          }

          const catLines: string[] = [];
          const estimatedHeader = theme.fg("accent", theme.bold("Estimated usage by category"));
          // header will be injected separately, not in catLines

          for (const cat of visibleCategories) {
            // Friendly label: Skills shows count
            let displayLabel = cat.label;
            if (cat.label === "Skills" && showAll && skillsDetail.length > 0) {
              displayLabel = `Skills (${skillsDetail.length})`;
            } else if (cat.label === "Memory files" && showAll && memoryFilesDetail.length > 0) {
              // Keep label but could hint count; stay as is to avoid width blow-up
            }

            // Pad bare text then color — fixes ANSI length miscalc
            const labelBare = displayLabel.padEnd(18);
            const tokBare = cat.value === 0 ? "—".padStart(7) : formatTokens(cat.value).padStart(7);
            const pctBare = ((cat.value / limit) * 100).toFixed(1).padStart(5);

            let icon: string;
            let iconColor = cat.color;
            if (cat.isBuffer) {
              icon = SYMBOL_BUFFER;
              iconColor = "warning";
            } else if (cat.isFree) {
              icon = SYMBOL_EMPTY;
              iconColor = "borderMuted";
            } else {
              icon = usagePercent >= 70 ? SYMBOL_USED_HIGH : SYMBOL_USED_LOW;
            }

            catLines.push(
              `${theme.fg(iconColor as any, icon)} ${theme.fg("text", labelBare)} ${theme.fg("accent", tokBare)} ${theme.fg("dim", `(${pctBare}%)`)}`,
            );

            // Collapse details for negligible categories – keeps `all` readable.
            // Free/buffer have no items; tiny categories (<0.5%) stay folded.
            if (!showAll || cat.isFree || cat.isBuffer) {
              // no expansion
            } else if ((cat.value / limit) * 100 < DETAIL_MIN_PCT) {
              // small category – leave collapsed
            } else if (cat.label === "System tools") {
                if (systemToolsDetail.length === 0) {
                  catLines.push(`  ${theme.fg("dim", "∟ (no system tools)")}`);
                } else {
                  const slice = systemToolsDetail.slice(0, MAX_DETAIL_ITEMS);
                  for (const d of slice) {
                    const p = ((d.tokens / limit) * 100).toFixed(1).padStart(5);
                    const tk = formatTokens(d.tokens).padStart(7);
                    const name = truncateLabel(d.name, 16).padEnd(16);
                    catLines.push(
                      `  ${theme.fg("dim", "∟")} ${theme.fg("text", name)} ${theme.fg("accent", tk)} ${theme.fg("dim", `(${p}%)`)}`,
                    );
                  }
                  if (systemToolsDetail.length > MAX_DETAIL_ITEMS) {
                    catLines.push(
                      `  ${theme.fg("dim", `∟ +${systemToolsDetail.length - MAX_DETAIL_ITEMS} more`)}`,
                    );
                  }
                }
              } else if (cat.label === "Extension tools") {
                if (extensionToolsDetail.length === 0) {
                  catLines.push(`  ${theme.fg("dim", "∟ (no extension tools)")}`);
                } else {
                  const slice = extensionToolsDetail.slice(0, MAX_DETAIL_ITEMS);
                  for (const d of slice) {
                    const p = ((d.tokens / limit) * 100).toFixed(1).padStart(5);
                    const tk = formatTokens(d.tokens).padStart(7);
                    const name = truncateLabel(d.name, 16).padEnd(16);
                    catLines.push(
                      `  ${theme.fg("dim", "∟")} ${theme.fg("text", name)} ${theme.fg("accent", tk)} ${theme.fg("dim", `(${p}%)`)}`,
                    );
                  }
                  if (extensionToolsDetail.length > MAX_DETAIL_ITEMS) {
                    catLines.push(
                      `  ${theme.fg("dim", `∟ +${extensionToolsDetail.length - MAX_DETAIL_ITEMS} more`)}`,
                    );
                  }
                }
              } else if (cat.label === "Memory files") {
                if (memoryFilesDetail.length === 0) {
                  catLines.push(`  ${theme.fg("dim", "∟ (no memory files)")}`);
                } else {
                  const slice = memoryFilesDetail.slice(0, MAX_DETAIL_ITEMS);
                  for (const d of slice) {
                    const p = ((d.tokens / limit) * 100).toFixed(1).padStart(5);
                    const tk = formatTokens(d.tokens).padStart(7);
                    const short = truncateLabel(d.base, 16).padEnd(16);
                    catLines.push(
                      `  ${theme.fg("dim", "∟")} ${theme.fg("text", short)} ${theme.fg("accent", tk)} ${theme.fg("dim", `(${p}%)`)}`,
                    );
                  }
                  if (memoryFilesDetail.length > MAX_DETAIL_ITEMS) {
                    catLines.push(
                      `  ${theme.fg("dim", `∟ +${memoryFilesDetail.length - MAX_DETAIL_ITEMS} more`)}`,
                    );
                  }
                }
              } else if (cat.label === "Skills") {
                if (skillsDetail.length === 0) {
                  catLines.push(`  ${theme.fg("dim", "∟ (no skills)")}`);
                } else {
                  const slice = skillsDetail.slice(0, MAX_DETAIL_ITEMS);
                  for (const d of slice) {
                    const p = ((d.tokens / limit) * 100).toFixed(1).padStart(5);
                    const tk = formatTokens(d.tokens).padStart(7);
                    const lab = truncateLabel(d.label, 16).padEnd(16);
                    catLines.push(
                      `  ${theme.fg("dim", "∟")} ${theme.fg("text", lab)} ${theme.fg("accent", tk)} ${theme.fg("dim", `(${p}%)`)}`,
                    );
                  }
                  if (skillsDetail.length > MAX_DETAIL_ITEMS) {
                    catLines.push(
                      `  ${theme.fg("dim", `∟ +${skillsDetail.length - MAX_DETAIL_ITEMS} more`)}`,
                    );
                  }
                }
              } else if (cat.label === "Messages") {
                const roles = Object.entries(messagesByRole).filter(([, v]) => v > 0);
                if (roles.length === 0) {
                  catLines.push(`  ${theme.fg("dim", "∟ (no messages)")}`);
                } else {
                  const slice = roles.slice(0, MAX_DETAIL_ITEMS);
                  for (const [role, tokVal] of slice) {
                    const p = ((tokVal / limit) * 100).toFixed(1).padStart(5);
                    const tk = formatTokens(tokVal).padStart(7);
                    const friendly = truncateLabel(displayRole(role), 16).padEnd(16);
                    catLines.push(
                      `  ${theme.fg("dim", "∟")} ${theme.fg("text", friendly)} ${theme.fg("accent", tk)} ${theme.fg("dim", `(${p}%)`)}`,
                    );
                  }
                  if (roles.length > MAX_DETAIL_ITEMS) {
                    catLines.push(
                      `  ${theme.fg("dim", `∟ +${roles.length - MAX_DETAIL_ITEMS} more`)}`,
                    );
                  }
                }
              }
          }

          return { gridLines, catLines, estimatedHeader, gridWidth };
        };

        let cachedWidth = 0;
        let cachedContainer: Container | null = null;

        const makeContainer = (w: number) => {
          const c = new Container();
          c.addChild(new DynamicBorder((s: string) => theme.fg("accent", s)));
          c.addChild(new Text(theme.fg("accent", theme.bold(" Context Usage")), 1, 0));
          c.addChild(new Spacer(1));

          const modelHeaderLocal = `${theme.fg("muted", headerModel)} ${theme.fg("dim", "·")} ${theme.fg("text", theme.bold(formatTokens(totalActual)))}${theme.fg("dim", "/")}${theme.fg("dim", formatTokens(limit))} ${theme.fg("text", theme.bold(`(${usagePercent.toFixed(1)}%)`))}`;
          c.addChild(new Text(`  ${modelHeaderLocal}`, 1, 0));
          c.addChild(new Text(theme.fg("dim", "  Model context window usage — grid shows used(⛁/⛀) vs buffer(⛝) vs free(⛶)"), 1, 0));
          c.addChild(new Spacer(1));

          const { gridLines, catLines, estimatedHeader, gridWidth } = buildContent(w);

          // Vertical layout: grid centered, then usage list — avoids side-by-side ANSI pad issues
          const visibleGridWidth = gridWidth * 2 - 1;
          const padLeft = Math.max(0, Math.floor((w - visibleGridWidth) / 2) - 2);
          const padSpaces = " ".repeat(padLeft);

          for (const gl of gridLines) {
            c.addChild(new Text(`  ${padSpaces}${gl}`, 1, 0));
          }

          c.addChild(new Spacer(1));

          // Total Usage — bare pad then color, no ANSI length drift, single line at 174-wide
          const totalLabelBare = "Total Usage".padEnd(18);
          const totalTokBare = formatTokens(totalActual).padStart(7);
          const totalPctBare = usagePercent.toFixed(1).padStart(5);
          const totalLine = `${theme.fg("text", theme.bold(totalLabelBare))} ${theme.fg("accent", theme.bold(totalTokBare))} ${theme.fg("dim", theme.bold(`(${totalPctBare}%)`))}`;
          c.addChild(new Text(`  ${totalLine}`, 1, 0));
          c.addChild(new Spacer(1));
          c.addChild(new Text(`  ${estimatedHeader}`, 1, 0));
          for (const cl of catLines) {
            c.addChild(new Text(`  ${cl}`, 1, 0));
          }
          c.addChild(new Text(theme.fg("dim", "  * Pi default: 16,384 tokens; custom setting unavailable here"), 1, 0));

          // Height guard: if showAll truncated items, hint
          const truncated =
            (showAll &&
              (systemToolsDetail.length > MAX_DETAIL_ITEMS ||
                extensionToolsDetail.length > MAX_DETAIL_ITEMS ||
                memoryFilesDetail.length > MAX_DETAIL_ITEMS ||
                skillsDetail.length > MAX_DETAIL_ITEMS)) ||
            false;

          if (truncated) {
            c.addChild(new Spacer(1));
            c.addChild(new Text(theme.fg("dim", `  ↕ showing first ${MAX_DETAIL_ITEMS} per category`), 1, 0));
          } else if (showAll && catLines.length > 28) {
            c.addChild(new Spacer(1));
            c.addChild(new Text(theme.fg("dim", "  ↕ long list — ↑/↓ scroll if content exceeds view"), 1, 0));
          }

          c.addChild(new Spacer(1));

          const warnings: string[] = [];
          if (overflowTokens > 0) {
            warnings.push(
              theme.fg("error", theme.bold(`⚠ Context overflow: ${formatTokens(overflowTokens)} over limit`)) +
                ` ${theme.fg("dim", `(${formatTokens(totalActual)}/${formatTokens(limit)})`)}`,
            );
            warnings.push(theme.fg("warning", "  → Run /compact to compact the conversation"));
          } else if (usagePercent >= 90) {
            warnings.push(theme.fg("error", `⚠ High usage: ${usagePercent.toFixed(1)}% – near limit`));
            warnings.push(theme.fg("warning", "  → Consider /compact with a handoff summary"));
          } else if (usagePercent >= 70) {
            warnings.push(theme.fg("warning", `⚠ Usage at ${usagePercent.toFixed(1)}% – approaching limit`));
            warnings.push(theme.fg("dim", "  → Create a checkpoint before continuing"));
          }

          const heavy = visibleCategories.filter((cat) => !cat.isFree && !cat.isBuffer && (cat.value / limit) * 100 > 10);
          if (heavy.length > 0 && usagePercent >= 50) {
            for (const h of heavy) {
              const pct = ((h.value / limit) * 100).toFixed(1);
              if (h.label === "Messages") {
                warnings.push(theme.fg("dim", `  • Messages at ${pct}% – consider compacting completed segments`));
              } else if (h.label === "Extension tools" || h.label === "System tools") {
                warnings.push(theme.fg("dim", `  • ${h.label} at ${pct}% – review active tools`));
              } else if (h.label === "Memory files") {
                warnings.push(theme.fg("dim", `  • Memory files at ${pct}% – large AGENTS.md/context files`));
              } else {
                warnings.push(theme.fg("dim", `  • ${h.label} at ${pct}% – may be optimizable`));
              }
            }
          }

          if (warnings.length > 0) {
            for (const wline of warnings) {
              c.addChild(new Text(`  ${wline}`, 1, 0));
            }
            c.addChild(new Spacer(1));
          }

          if (showAll) {
            c.addChild(new Text(theme.fg("dim", "  Showing per-item breakdown (/context all)"), 1, 0));
          }

          // Friendly tip area
          if (w < 100) {
            c.addChild(new Text(theme.fg("dim", "  Tip: /context all shows details • /compact frees space when >70%"), 1, 0));
            c.addChild(new Text(theme.fg("dim", "       checkpoint before noisy work"), 1, 0));
          } else {
            c.addChild(
              new Text(
                theme.fg("dim", "  Tip: /context all shows per-item details • /compact frees space when >70% • checkpoint before noisy work"),
                1,
                0,
              ),
            );
          }

          c.addChild(new Spacer(1));

          // More visible close hint, centered
          const closeText = "◀ Press any key to close ▶";
          const closePad = Math.max(0, Math.floor((w - closeText.length) / 2) - 2);
          c.addChild(new Text(`${" ".repeat(2 + closePad)}${theme.fg("accent", theme.bold(closeText))}`, 1, 0));

          c.addChild(new DynamicBorder((s: string) => theme.fg("accent", s)));
          return c;
        };

        return {
          render: (w: number) => {
            if (!cachedContainer || w !== cachedWidth) {
              cachedWidth = w;
              cachedContainer = makeContainer(w);
            }
            return cachedContainer.render(w);
          },
          invalidate: () => {
            cachedContainer?.invalidate();
          },
          handleInput: (_data: string) => done(undefined),
        };
      }, { overlay: true });
    },
  });
}
