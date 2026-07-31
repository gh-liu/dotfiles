import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { renderMermaidASCII } from "beautiful-mermaid";

const SOURCE_ENTRY_TYPE = "mermaid-ascii-source";
const MERMAID_FENCE =
  /(^|\n)([ \t]*)(`{3,}|~{3,})[ \t]*mermaid[^\r\n]*\r?\n([\s\S]*?)\r?\n\2\3[ \t]*(?=\r?\n|$)/gi;

interface SourceEntry {
  replacements: Array<{
    rendered: string;
    source: string;
  }>;
}

function renderMermaidBlocks(text: string, replacements: SourceEntry["replacements"]): string {
  return text.replace(
    MERMAID_FENCE,
    (source, prefix: string, indent: string, fence: string, diagram: string) => {
      try {
        const rendered = renderMermaidASCII(diagram, {
          colorMode: "none",
          paddingX: 3,
          paddingY: 1,
        });
        const block = `${prefix}${indent}${fence}text\n${rendered}\n${indent}${fence}`;
        replacements.push({ rendered: block, source });
        return block;
      } catch {
        return source;
      }
    },
  );
}

function isSourceEntry(data: unknown): data is SourceEntry {
  if (!data || typeof data !== "object" || !("replacements" in data)) return false;
  const { replacements } = data as SourceEntry;
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

export default function mermaid(pi: ExtensionAPI) {
  pi.on("message_end", (event) => {
    if (event.message.role !== "assistant") return;

    const replacements: SourceEntry["replacements"] = [];
    const content = event.message.content.map((part) =>
      part.type === "text"
        ? { ...part, text: renderMermaidBlocks(part.text, replacements) }
        : part,
    );
    if (replacements.length === 0) return;

    pi.appendEntry(SOURCE_ENTRY_TYPE, { replacements } satisfies SourceEntry);
    return { message: { ...event.message, content } };
  });

  pi.on("context", (event, ctx) => {
    const replacements = ctx.sessionManager
      .getBranch()
      .flatMap((entry) =>
        entry.type === "custom" &&
          entry.customType === SOURCE_ENTRY_TYPE &&
          isSourceEntry(entry.data)
          ? entry.data.replacements
          : [],
      );
    if (replacements.length === 0) return;

    return {
      messages: event.messages.map((message) =>
        message.role === "assistant"
          ? {
            ...message,
            content: message.content.map((part) => {
              if (part.type !== "text") return part;
              let text = part.text;
              for (const replacement of replacements) {
                text = text.replaceAll(replacement.rendered, replacement.source);
              }
              return text === part.text ? part : { ...part, text };
            }),
          }
          : message,
      ),
    };
  });
}
