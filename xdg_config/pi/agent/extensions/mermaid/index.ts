import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { renderMermaidSVG } from "beautiful-mermaid";

const SOURCE_ENTRY_TYPE = "mermaid-ascii-source";
const MERMAID_FENCE =
  /(^|\n)([ \t]*)((`|~)\4{2,})[ \t]*mermaid[^\r\n]*\r?\n([\s\S]*?)\r?\n[ \t]*\3\4*[ \t]*(?=\r?\n|$)/gi;
const GENERATED_LINK =
  /(^|\n)([ \t]*)(?:\[Open Mermaid diagram ↗\]\(file:\/\/\/[^)\r\n]+\/[a-f0-9]{64}\.svg\)|`mermaid` · \[Open diagram ↗\]\(file:\/\/\/[^)\r\n]+\/[a-f0-9]{64}\.svg\))\r?\n(?=\2(?:`{3,}|~{3,})[ \t]*mermaid)/gi;

interface Replacement {
  rendered: string;
  source: string;
}

interface LegacySourceEntry {
  replacements: Replacement[];
}

interface SourceEntry {
  messageTimestamp: number;
  parts: Array<{
    index: number;
    replacements: Replacement[];
  }>;
}

function getCacheDirectory(): string {
  return join(process.env.HOME ?? homedir(), ".pi", "cache", "mermaid");
}

function renderMermaidLink(diagram: string): string {
  const cacheDirectory = getCacheDirectory();
  const filename = `${createHash("sha256").update("svg-v1\0").update(diagram).digest("hex")}.svg`;
  const path = join(cacheDirectory, filename);
  if (!existsSync(path)) {
    const svg = renderMermaidSVG(diagram, {
      bg: "#ffffff",
      fg: "#111827",
    });
    mkdirSync(cacheDirectory, { recursive: true });
    writeFileSync(path, svg, "utf8");
  }
  return `[Open Mermaid diagram ↗](${pathToFileURL(path).href})`;
}

function renderMermaidBlocks(text: string): string {
  return text.replace(GENERATED_LINK, "$1").replace(
    MERMAID_FENCE,
    (
      source,
      prefix: string,
      indent: string,
      fence: string,
      _fenceCharacter: string,
      diagram: string,
    ) => {
      try {
        return `${prefix}${indent}${renderMermaidLink(diagram)}\n${source.slice(prefix.length)}`;
      } catch {
        return source;
      }
    },
  );
}

function isLegacySourceEntry(data: unknown): data is LegacySourceEntry {
  if (!data || typeof data !== "object" || !("replacements" in data)) return false;
  const { replacements } = data as LegacySourceEntry;
  return (
    Array.isArray(replacements) &&
    replacements.every(
      (replacement) =>
        replacement &&
        typeof replacement.rendered === "string" &&
        typeof replacement.source === "string",
    )
  );
}

function isSourceEntry(data: unknown): data is SourceEntry {
  if (!data || typeof data !== "object" || !("parts" in data)) return false;
  const { messageTimestamp, parts } = data as SourceEntry;
  return (
    typeof messageTimestamp === "number" &&
    Array.isArray(parts) &&
    parts.every(
      (part) =>
        part &&
        Number.isInteger(part.index) &&
        part.index >= 0 &&
        Array.isArray(part.replacements) &&
        part.replacements.length > 0 &&
        part.replacements.every(
          (replacement) =>
            replacement &&
            typeof replacement.rendered === "string" &&
            typeof replacement.source === "string",
        ),
    )
  );
}

function restoreReplacements(text: string, replacements: Replacement[]): string | undefined {
  for (const replacement of replacements) {
    if (!text.includes(replacement.rendered)) return undefined;
    text = text.replace(replacement.rendered, replacement.source);
  }
  return text;
}

export default function mermaid(pi: ExtensionAPI) {
  pi.registerMarkdownTransformer((markdown, { messageType, isStreaming }) => {
    if (messageType !== "assistant" || isStreaming) return markdown;
    return renderMermaidBlocks(markdown);
  });

  pi.on("context", (event, ctx) => {
    const sourceEntries = ctx.sessionManager
      .getBranch()
      .flatMap((entry) =>
        entry.type === "custom" &&
          entry.customType === SOURCE_ENTRY_TYPE &&
          (isSourceEntry(entry.data) || isLegacySourceEntry(entry.data))
          ? [entry.data]
          : [],
      );
    if (sourceEntries.length === 0) return;

    const messages = [...event.messages];
    const restoredMessageIndexes = new Set<number>();
    for (const sourceEntry of sourceEntries) {
      if (isSourceEntry(sourceEntry)) {
        const messageIndex = messages.findIndex(
          (message, index) =>
            !restoredMessageIndexes.has(index) &&
            message.role === "assistant" &&
            message.timestamp === sourceEntry.messageTimestamp &&
            sourceEntry.parts.every(({ index: partIndex, replacements }) => {
              const part = message.content[partIndex];
              return (
                part?.type === "text" && restoreReplacements(part.text, replacements) !== undefined
              );
            }),
        );
        if (messageIndex === -1) continue;

        const message = messages[messageIndex];
        if (message.role !== "assistant") continue;

        const content = [...message.content];
        for (const { index, replacements } of sourceEntry.parts) {
          const part = content[index];
          if (part?.type !== "text") continue;
          const restored = restoreReplacements(part.text, replacements);
          if (restored !== undefined) content[index] = { ...part, text: restored };
        }
        messages[messageIndex] = { ...message, content };
        restoredMessageIndexes.add(messageIndex);
        continue;
      }

      for (const replacement of sourceEntry.replacements) {
        for (let messageIndex = 0; messageIndex < messages.length; messageIndex++) {
          const message = messages[messageIndex];
          if (message.role !== "assistant") continue;
          const partIndex = message.content.findIndex(
            (part) => part.type === "text" && part.text.includes(replacement.rendered),
          );
          if (partIndex === -1) continue;

          const content = [...message.content];
          const part = content[partIndex];
          if (part.type !== "text") continue;
          const restored = restoreReplacements(part.text, [replacement]);
          if (restored === undefined) continue;
          content[partIndex] = { ...part, text: restored };
          messages[messageIndex] = { ...message, content };
          break;
        }
      }
    }

    return { messages };
  });
}
