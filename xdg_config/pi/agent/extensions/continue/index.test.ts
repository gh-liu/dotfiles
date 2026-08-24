import { describe, expect, test } from "vitest";
import { buildContinuationPrompt } from "./index.ts";

describe("buildContinuationPrompt", () => {
  test("uses the summary and worktree first, then continues execution", () => {
    const prompt = buildContinuationPrompt("/tmp/session.jsonl", "compact-7");

    expect(prompt).toContain("compaction summary and the current worktree as the primary sources");
    expect(prompt).toContain("recover the goal, constraints, progress, decisions, and next unfinished step");
    expect(prompt).toContain("Execute the next unfinished step");
    expect(prompt).toContain("do not stop at a recap");
  });

  test("makes persisted JSONL a conditional, parent-linked fallback", () => {
    const prompt = buildContinuationPrompt("/tmp/session.jsonl", "compact-7");

    expect(prompt).toContain("Only if a decision-critical detail is missing, contradictory, or ambiguous");
    expect(prompt).toContain('"/tmp/session.jsonl"');
    expect(prompt).toContain('compaction entry "compact-7"');
    expect(prompt).toContain("follow parentId links backward");
    expect(prompt).toContain("never infer the active branch from JSONL append order");
    expect(prompt).toContain("Do not launch nested Pi");
    expect(prompt).toContain("Ask the user only if the needed context remains genuinely unavailable or ambiguous");
  });

  test("keeps ephemeral recovery safe without suggesting JSONL access", () => {
    const prompt = buildContinuationPrompt(undefined, "compact-7");

    expect(prompt).toContain("ephemeral");
    expect(prompt).toContain("no persisted JSONL is available");
    expect(prompt).not.toContain("parentId");
    expect(prompt).not.toContain("read/bash");
    expect(prompt).toContain("ask the user only if a decision-critical detail is genuinely unavailable or ambiguous");
  });

  test("fits a meaningful reduced prompt-size budget", () => {
    const persisted = buildContinuationPrompt("/sessions/1234567890abcdef/session.jsonl", "01JABCDEF0123456789");
    const ephemeral = buildContinuationPrompt(undefined, "01JABCDEF0123456789");

    expect(persisted.length).toBeLessThan(1_000);
    expect(ephemeral.length).toBeLessThan(750);
  });
});
