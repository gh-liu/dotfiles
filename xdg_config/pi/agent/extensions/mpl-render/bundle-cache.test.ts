import { expect, test, vi } from "vitest";

// Holds the missing-file read open so a later, successful read can replace the cache entry
// before this one fails. A real filesystem cannot order those two outcomes.
const pending = vi.hoisted(() => ({
  rejectSlow: undefined as ((error: Error) => void) | undefined,
  reads: 0,
  reset() {
    this.rejectSlow = undefined;
    this.reads = 0;
  },
}));

vi.mock("node:fs/promises", () => ({
  readFile: (url: URL) => {
    pending.reads += 1;
    if (String(url).includes("slow-missing") && !pending.rejectSlow) {
      return new Promise((_resolve, reject) => {
        pending.rejectSlow = reject;
      });
    }
    return Promise.resolve("var mpl = {};\n");
  },
}));

const { loadBundle } = await import("./index.ts");

test("a failed bundle read drops only its own cache entry", async () => {
  pending.reset();
  const slow = loadBundle(new URL("file:///slow-missing.js"));
  await expect(loadBundle(new URL("file:///good.js"))).resolves.toBe(JSON.stringify("var mpl = {};\n"));
  const readsAfterGood = pending.reads;

  expect(pending.rejectSlow).toBeTypeOf("function");
  pending.rejectSlow?.(new Error("ENOENT"));
  await expect(slow).rejects.toThrow("Run `npm run build` in");

  await loadBundle(new URL("file:///good.js"));
  expect(pending.reads).toBe(readsAfterGood);
});

test("an older failure does not discard a newer read of the same URL", async () => {
  pending.reset();
  const url = new URL("file:///slow-missing-again.js");
  const slow = loadBundle(url);
  await loadBundle(new URL("file:///other.js"));
  await loadBundle(url);
  const readsAfterNewer = pending.reads;

  expect(pending.rejectSlow).toBeTypeOf("function");
  pending.rejectSlow?.(new Error("ENOENT"));
  await expect(slow).rejects.toThrow("Run `npm run build` in");
  await loadBundle(url);
  expect(pending.reads).toBe(readsAfterNewer);
});
