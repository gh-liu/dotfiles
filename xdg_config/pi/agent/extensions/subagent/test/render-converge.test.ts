import { describe, expect, test } from "vitest";

import { renderActivityRow, renderDetailSections } from "../render/shared.ts";

const theme = {
  fg: (_color: string, text: string) => text,
  bold: (text: string) => text,
} as never;

describe("render收敛快照", () => {
  test("renderDetailSections跳过空值并截断超长", () => {
    const text = renderDetailSections(
      [["Task", "do work"], ["Summary", ""], ["Changes", undefined], ["Risks", "risk  "] ].map(([label, value]) => [label, value as string | undefined] as [string, string | undefined]),
      theme,
    );
    expect(text).toContain("Task");
    expect(text).not.toContain("Summary");
    expect(text).not.toContain("Changes");
    expect(text).toContain("risk");
  });

  test("renderActivityRow单行正规化三形态快照", () => {
    expect(renderActivityRow("✓ Thinking", theme)).toBe("✓ Thinking");
    expect(renderActivityRow("✓ grep auth.ts", theme)).toContain("grep");
    expect(renderActivityRow("✗ npm test failed", theme)).toContain("npm test");
    expect(renderActivityRow("plain line without marker", theme)).toContain("plain line");
    const long = renderActivityRow(`✓ ${"x".repeat(500)}`, theme);
    expect(long.length).toBeLessThanOrEqual(220);
  });

  test("超长section截断保持20行4000字符界", () => {
    const big = Array.from({ length: 30 }, (_, i) => `line-${i}-${"y".repeat(300)}`).join("\n");
    const text = renderDetailSections([["Summary", big]], theme);
    expect(text.length).toBeLessThan(5_000);
    expect(text.endsWith("…") || text.includes("…")).toBe(true);
  });
});
