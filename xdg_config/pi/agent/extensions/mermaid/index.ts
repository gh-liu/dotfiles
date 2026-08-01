import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { createHash } from "node:crypto";
import { mkdirSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { renderMermaidSVG } from "beautiful-mermaid";

const SOURCE_ENTRY_TYPE = "mermaid-ascii-source";
const MERMAID_FENCE =
  /(^|\n)([ \t]*)((`|~)\4{2,})[ \t]*mermaid[^\r\n]*\r?\n([\s\S]*?)\r?\n[ \t]*\3\4*[ \t]*(?=\r?\n|$)/gi;

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
  const cacheRoot =
    process.env.XDG_CACHE_HOME ??
    (process.platform === "darwin"
      ? join(homedir(), "Library", "Caches")
      : join(homedir(), ".cache"));
  return join(cacheRoot, "pi", "mermaid");
}

function renderMermaidLink(diagram: string): string {
  const svg = renderMermaidSVG(diagram, {
    bg: "#ffffff",
    fg: "#111827",
  });
  const cacheDirectory = getCacheDirectory();
  const filename = `${createHash("sha256").update(diagram).digest("hex")}.svg`;
  const path = join(cacheDirectory, filename);
  mkdirSync(cacheDirectory, { recursive: true });
  writeFileSync(path, svg, "utf8");
  return `[Open Mermaid diagram ↗](${pathToFileURL(path).href})`;
}

function renderMermaidBlocks(text: string, replacements: Replacement[]): string {
  return text.replace(
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
        const block = `${prefix}${indent}${renderMermaidLink(diagram)}\n${source.slice(prefix.length)}`;
        replacements.push({ rendered: block, source });
        return block;
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
  pi.on("message_end", (event) => {
    if (event.message.role !== "assistant") return;

    const parts: SourceEntry["parts"] = [];
    const content = event.message.content.map((part, index) => {
      if (part.type !== "text") return part;
      const replacements: Replacement[] = [];
      const rendered = renderMermaidBlocks(part.text, replacements);
      if (replacements.length === 0) return part;
      parts.push({ index, replacements });
      return { ...part, text: rendered };
    });
    if (parts.length === 0) return;

    pi.appendEntry(SOURCE_ENTRY_TYPE, {
      messageTimestamp: event.message.timestamp,
      parts,
    } satisfies SourceEntry);
    return { message: { ...event.message, content } };
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
                part?.type === "text" &&
                restoreReplacements(part.text, replacements) !== undefined
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
