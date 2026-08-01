import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

import mermaid from "./index.ts";

const originalHome = process.env.HOME;
const testHome = mkdtempSync(join(tmpdir(), "pi-mermaid-test-"));

beforeAll(() => {
  process.env.HOME = testHome;
});

afterAll(() => {
  if (originalHome === undefined) delete process.env.HOME;
  else process.env.HOME = originalHome;
  rmSync(testHome, { recursive: true, force: true });
});

function setup(entries: any[] = []) {
  const handlers = new Map<string, (...args: any[]) => any>();
  let transformer: ((markdown: string, context: any) => string) | undefined;
  const pi = {
    on: (name: string, handler: (...args: any[]) => any) => handlers.set(name, handler),
    registerMarkdownTransformer: (registered: typeof transformer) => {
      transformer = registered;
    },
  } as unknown as ExtensionAPI;
  mermaid(pi);

  const transform = (
    markdown: string,
    context: { messageType: string; isStreaming: boolean } = {
      messageType: "assistant",
      isStreaming: false,
    },
  ) => transformer!(markdown, { ...context, availableWidth: 120 });
  const restore = (messages: any[]) =>
    handlers.get("context")?.(
      { messages },
      { sessionManager: { getBranch: () => entries } },
    )?.messages;

  return { restore, transform };
}

function getSvgUrl(markdown: string): string | undefined {
  return markdown.match(/\[Open Mermaid diagram ↗\]\((file:\/\/[^)]+)\)/)?.[1];
}

describe("mermaid extension", () => {
  test("adds an SVG link while preserving the Mermaid block", () => {
    const { transform } = setup();
    const block = "```mermaid\ngraph LR\n  A --> B\n```";
    const source = `Before\n${block}\nAfter`;

    const rendered = transform(source);
    const url = getSvgUrl(rendered);

    expect(url).toBeDefined();
    expect(rendered).toContain(block);
    expect(fileURLToPath(url!)).toStartWith(join(testHome, ".pi", "cache", "mermaid") + "/");
    expect(readFileSync(fileURLToPath(url!), "utf8")).toStartWith("<svg");
    expect(source).toBe(`Before\n${block}\nAfter`);
  });

  test("does not transform user, thinking, or streaming Markdown", () => {
    const { transform } = setup();
    const source = "```mermaid\ngraph LR\nA --> B\n```";

    expect(transform(source, { messageType: "user", isStreaming: false })).toBe(source);
    expect(transform(source, { messageType: "assistant-thinking", isStreaming: false })).toBe(
      source,
    );
    expect(transform(source, { messageType: "assistant", isStreaming: true })).toBe(source);
  });

  test("transforms multiple blocks and supports a longer closing fence", () => {
    const { transform } = setup();
    const firstBlock = "```mermaid\ngraph LR\nA --> B\n````";
    const secondBlock = "```mermaid\nsequenceDiagram\nA->>B: hello\n```";
    const source = `${firstBlock}\n${secondBlock}`;

    const rendered = transform(source);

    expect(rendered.match(/\[Open Mermaid diagram ↗\]/g)).toHaveLength(2);
    expect(rendered).toContain(firstBlock);
    expect(rendered).toContain(secondBlock);
  });

  test("replaces a persisted generated link instead of duplicating it", () => {
    const { transform } = setup();
    const source = "```mermaid\ngraph LR\nA --> B\n```";
    const first = transform(source);

    const second = transform(first);

    expect(second.match(/\[Open Mermaid diagram ↗\]/g)).toHaveLength(1);
    expect(second).toContain(source);
  });

  test("recreates an evicted SVG from restored Markdown", () => {
    const { transform } = setup();
    const source = "```mermaid\ngraph LR\nA --> B\n```";
    const rendered = transform(source);
    const path = fileURLToPath(getSvgUrl(rendered)!);
    rmSync(path);

    transform(rendered);

    expect(readFileSync(path, "utf8")).toStartWith("<svg");
  });

  test("leaves invalid Mermaid unchanged", () => {
    const { transform } = setup();
    const source = "```mermaid\nnot a diagram\n```";

    expect(transform(source)).toBe(source);
  });

  test("restores messages written by the previous extension version", () => {
    const source = "```mermaid\ngraph LR\nA --> B\n```";
    const rendered = `[Open Mermaid diagram ↗](file:///tmp/${"a".repeat(64)}.svg)\n${source}`;
    const entries = [
      {
        type: "custom",
        customType: "mermaid-ascii-source",
        data: {
          messageTimestamp: 7,
          parts: [{ index: 0, replacements: [{ rendered, source }] }],
        },
      },
    ];
    const { restore } = setup(entries);
    const message = {
      role: "assistant",
      timestamp: 7,
      content: [{ type: "text", text: rendered }],
    };

    expect(restore([message])[0].content[0].text).toBe(source);
  });
});
