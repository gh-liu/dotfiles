import { describe, expect, test } from "vitest";

import { normalizeProgress } from "../progress.ts";

describe("normalizeProgress", () => {
  test("bounds超长summary为单行240", () => {
    const long = `${"x".repeat(500)}\nsecond line`;
    const normalized = normalizeProgress({ summary: long });
    expect(normalized.summary.length).toBeLessThanOrEqual(240);
    expect(normalized.summary).not.toContain("\n");
  });

  test("超长timeline只保留最近8条recentActivity且单行 bounded", () => {
    const timeline = Array.from({ length: 20 }, (_, i) => ({
      kind: "tool" as const,
      id: `t${i}`,
      summary: `${"y".repeat(300)} ${i}`,
      status: "completed" as const,
    }));
    const normalized = normalizeProgress({ summary: "s", timeline });
    expect(normalized.recentActivity).toHaveLength(8);
    for (const row of normalized.recentActivity) expect(row.length).toBeLessThanOrEqual(162);
    expect(normalized.timeline).toHaveLength(20);
    expect(normalized.timeline).not.toBe(timeline);
  });

  test("tool/active原样深拷贝且activeCount可消费", () => {
    const tools = {
      earlierCount: 5,
      history: [{ id: "h", summary: "grep a", status: "completed" as const }],
      active: [
        { id: "a1", summary: "read b", status: "running" as const },
        { id: "a2", summary: "read c", status: "running" as const },
      ],
    };
    const normalized = normalizeProgress({ summary: "s", tools });
    expect(normalized.tools?.earlierCount).toBe(5);
    expect(normalized.tools?.active).toHaveLength(2);
    expect(normalized.activeCount).toBe(2);
    expect(normalized.tools).not.toBe(tools);
  });

  test("哨兵decision: 空question不透出, 非法options丢弃, 超长截断且最多8个", () => {
    expect(normalizeProgress({ summary: "s", needsDecision: true }).needsDecision).toBeUndefined();
    expect(
      normalizeProgress({ summary: "s", needsDecision: true, decision: { question: "   " } }).needsDecision,
    ).toBeUndefined();
    const options = Array.from({ length: 10 }, (_, i) => (i % 3 === 0 ? "" : `${"z".repeat(300)}${i}`));
    const normalized = normalizeProgress({
      summary: "s",
      needsDecision: true,
      decision: { question: `  ${"q".repeat(500)}  `, options },
    });
    expect(normalized.needsDecision).toBe(true);
    expect(normalized.question?.length).toBeLessThanOrEqual(240);
    expect(normalized.decision?.options?.length).toBeLessThanOrEqual(8);
    for (const option of normalized.decision?.options ?? []) expect(option.length).toBeLessThanOrEqual(240);
  });

  test("string输入收敛为同结果且phase透传拷贝", () => {
    const fromString = normalizeProgress("hello");
    const fromObject = normalizeProgress({ summary: "hello" });
    expect(fromString.summary).toBe(fromObject.summary);
    const phase = { kind: "tool" as const, status: "running" as const };
    const normalized = normalizeProgress({ summary: "s", phase });
    expect(normalized.phase).toEqual(phase);
    expect(normalized.phase).not.toBe(phase);
  });
});
