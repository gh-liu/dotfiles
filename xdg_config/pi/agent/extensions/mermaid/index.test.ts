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

function setup() {
  const handlers = new Map<string, (...args: any[]) => any>();
  const entries: any[] = [];
  const pi = {
    on: (name: string, handler: (...args: any[]) => any) => handlers.set(name, handler),
    appendEntry: (customType: string, data: unknown) =>
      entries.push({ type: "custom", customType, data }),
  } as unknown as ExtensionAPI;
  mermaid(pi);

  const transform = (text: string, timestamp: number) =>
    handlers.get("message_end")?.({
      message: {
        role: "assistant",
        timestamp,
        content: [{ type: "text", text }],
      },
    })?.message;
  const restore = (messages: any[]) =>
    handlers.get("context")?.(
      { messages },
      { sessionManager: { getBranch: () => entries } },
    )?.messages;

  return { entries, restore, transform };
}

describe("mermaid extension", () => {
  test("preserves the Mermaid block, adds an SVG link, and restores its exact source", () => {
    const { restore, transform } = setup();
    const block = "```mermaid\ngraph LR\n  A --> B\n```";
    const source = `Before\n${block}\nAfter`;

    const rendered = transform(source, 1);
    const text = rendered.content[0].text;
    const url = text.match(/\[Open Mermaid diagram ↗\]\((file:\/\/[^)]+)\)/)?.[1];

    expect(url).toBeDefined();
    expect(text).toContain(block);
    expect(fileURLToPath(url!)).toStartWith(join(testHome, ".pi", "cache", "mermaid") + "/");
    expect(readFileSync(fileURLToPath(url!), "utf8")).toStartWith("<svg");
    expect(restore([rendered])[0].content[0].text).toBe(source);
  });

  test("restores multiple distinct sources independently", () => {
    const { restore, transform } = setup();
    const source = [
      "One",
      "```mermaid",
      "graph LR",
      "A --> B",
      "```",
      "Two",
      "```mermaid",
      "graph LR",
      "  A --> B",
      "```",
    ].join("\n");

    const rendered = transform(source, 2);

    expect(restore([rendered])[0].content[0].text).toBe(source);
  });

  test("does not restore a matching rendered block in another message", () => {
    const { restore, transform } = setup();
    const source = "```mermaid\ngraph LR\nA --> B\n```";
    const rendered = transform(source, 4);
    const unrelated = {
      ...rendered,
      timestamp: 3,
      content: rendered.content.map((part: any) => ({ ...part })),
    };

    const restored = restore([unrelated, rendered]);

    expect(restored[0]).toEqual(unrelated);
    expect(restored[1].content[0].text).toBe(source);
  });

  test("distinguishes messages with the same timestamp", () => {
    const { restore, transform } = setup();
    const firstSource = "```mermaid\ngraph LR\nA --> B\n```";
    const secondSource = "```mermaid\ngraph LR\n  A --> B\n```";

    const firstRendered = transform(firstSource, 5);
    const secondRendered = transform(secondSource, 5);
    const restored = restore([firstRendered, secondRendered]);

    expect(restored[0].content[0].text).toBe(firstSource);
    expect(restored[1].content[0].text).toBe(secondSource);
  });

  test("accepts a closing fence longer than the opening fence", () => {
    const { restore, transform } = setup();
    const source = "```mermaid\ngraph LR\nA --> B\n````";

    const rendered = transform(source, 5);

    expect(rendered.content[0].text).toContain("[Open Mermaid diagram ↗](file://");
    expect(rendered.content[0].text).toContain(source);
    expect(restore([rendered])[0].content[0].text).toBe(source);
  });

  test("restores entries written by the previous extension version", () => {
    const { entries, restore, transform } = setup();
    const source = "```mermaid\ngraph LR\nA --> B\n```";
    const rendered = transform(source, 6);
    const replacements = entries[0].data.parts[0].replacements;
    entries[0].data = { replacements };

    expect(restore([rendered])[0].content[0].text).toBe(source);
  });

  test("leaves invalid Mermaid unchanged", () => {
    const { entries, transform } = setup();
    const source = "```mermaid\nnot a diagram\n```";

    expect(transform(source, 7)).toBeUndefined();
    expect(entries).toEqual([]);
  });
});
