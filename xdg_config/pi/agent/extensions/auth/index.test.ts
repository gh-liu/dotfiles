import { beforeEach, describe, expect, test, vi } from "vitest";
import type { Credential, OAuthCredential } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import extension from "./index.ts";
import { codexAuth } from "./codex-auth.ts";

vi.mock("./codex-auth.ts", () => ({ codexAuth: vi.fn() }));
const source: OAuthCredential = { type: "oauth", access: "synthetic-access", refresh: "synthetic-refresh", accountId: "account", expires: 4_000_000_000_000 };

function setup(current?: Credential, hasUI = true) {
  let stored = current;
  let snapshotConfigured = current !== undefined;
  let handler!: (event: unknown, ctx: ExtensionContext) => Promise<void>;
  const modify = vi.fn(async (_provider: string, update: (value: Credential | undefined) => Promise<Credential | undefined>) => {
    const next = await update(stored);
    if (next) stored = next;
    return stored;
  });
  const refresh = vi.fn(async () => {
    snapshotConfigured = stored !== undefined;
    return { aborted: false, errors: new Map<string, Error>() };
  });
  const getProviderAuthStatus = vi.fn(() => (snapshotConfigured ? { configured: true as const, source: "stored" as const } : { configured: false as const }));
  const notify = vi.fn();
  const ctx = {
    hasUI,
    ui: { notify },
    modelRegistry: { runtime: { credentials: { modify } }, refresh, getProviderAuthStatus },
  } as unknown as ExtensionContext;
  const register = () => extension({ on: (_event: string, callback: typeof handler) => { handler = callback; } } as unknown as ExtensionAPI);
  register();
  return {
    start: () => handler({}, ctx),
    reload: () => register(),
    ctx,
    modify,
    refresh,
    getProviderAuthStatus,
    notify,
    stored: () => stored,
  };
}

beforeEach(() => vi.mocked(codexAuth).mockReset().mockResolvedValue([source, true]));

describe("Codex credential synchronization", () => {
  test("does not read secrets during factory loading; imports at session start and refreshes offline", async () => {
    const app = setup();
    expect(codexAuth).not.toHaveBeenCalled();
    await app.start();
    expect(app.stored()).toEqual(source);
    expect(app.refresh).toHaveBeenCalledWith({ allowNetwork: false, providers: ["openai-codex"] });
  });

  test.each([
    { ...source, access: "newer-access", refresh: "newer-refresh", expires: source.expires + 1 },
    { ...source, access: "rotated", refresh: "rotated", expires: source.expires },
    { ...source, expires: source.expires - 5_000 },
    { ...source, accountId: "different", expires: 1 },
    { type: "api_key" as const, key: "synthetic-key" },
    { ...source, access: "unknown-age", refresh: "unknown-age", expires: NaN },
  ])("preserves newer, equal, identical-token, different-account, API-key or unknown-age credentials", async (current) => {
    const app = setup(current);
    await app.start();
    expect(app.stored()).toEqual(current);
    expect(app.refresh).not.toHaveBeenCalled();
  });

  test("updates older same-account OAuth without losing provider metadata", async () => {
    const app = setup({ ...source, access: "older-access", refresh: "older-refresh", expires: 1, metadata: "keep" });
    await app.start();
    expect(app.stored()).toEqual({ ...source, metadata: "keep" });
  });

  test("checks latest store state and reads a fresh source at each session boundary", async () => {
    const app = setup();
    await app.start();
    vi.mocked(codexAuth).mockResolvedValue([{ ...source, access: "newer-access", refresh: "newer-refresh", expires: source.expires + 1 }, true]);
    await app.start();
    expect(app.stored()).toMatchObject({ access: "newer-access", expires: source.expires + 1 });
    expect(app.refresh).toHaveBeenCalledTimes(2);
  });

  test("an expired source may bootstrap missing auth but cannot replace existing auth", async () => {
    vi.mocked(codexAuth).mockResolvedValue([{ ...source, access: "expired-access", refresh: "expired-refresh", expires: 2 }, true]);
    const existing = setup({ ...source, access: "older-access", refresh: "older-refresh", expires: 1 });
    await existing.start();
    expect(existing.stored()).toMatchObject({ expires: 1 });
    const missing = setup();
    await missing.start();
    expect(missing.stored()).toMatchObject({ expires: 2 });
  });

  test("coalesces overlapping session starts without clobbering a subsequent in-flight sync", async () => {
    const app = setup();
    let releaseFirst!: () => void;
    let releaseSecond!: () => void;
    const firstGate = new Promise<void>((resolve) => { releaseFirst = resolve; });
    const secondGate = new Promise<void>((resolve) => { releaseSecond = resolve; });
    vi.mocked(codexAuth)
      .mockImplementationOnce(async () => { await firstGate; return [source, true]; })
      .mockImplementationOnce(async () => {
        await secondGate;
        return [{ ...source, access: "second-access", refresh: "second-refresh", expires: source.expires + 1 }, true];
      });

    const firstA = app.start();
    const firstB = app.start();
    let secondA!: Promise<void>;
    let secondB!: Promise<void>;
    const startSecondOnFirstA = firstA.then(() => {
      secondA = app.start();
      secondB = app.start();
    });

    releaseFirst();
    await Promise.all([firstA, firstB, startSecondOnFirstA]);
    // A fifth start while secondA/secondB are still pending must join them, not start a third sync.
    const secondC = app.start();
    releaseSecond();
    await Promise.all([secondA, secondB, secondC]);

    expect(codexAuth).toHaveBeenCalledTimes(2);
    expect(app.modify).toHaveBeenCalledTimes(2);
    expect(app.refresh).toHaveBeenCalledTimes(2);
  });

  test("refresh failure retries only refresh, not a successful write, without leaking errors", async () => {
    const app = setup();
    app.refresh.mockResolvedValueOnce({ aborted: false, errors: new Map([["openai-codex", new Error("synthetic-secret")]]) });
    await app.start();
    await app.start();
    expect(app.modify).toHaveBeenCalledTimes(1);
    expect(app.refresh).toHaveBeenCalledTimes(2);
    expect(JSON.stringify(app.notify.mock.calls)).not.toContain("synthetic-secret");
  });

  test("aborted refresh is treated as incomplete and retried", async () => {
    const app = setup();
    app.refresh.mockResolvedValueOnce({ aborted: true, errors: new Map() });
    await app.start();
    expect(app.notify).toHaveBeenCalledWith(expect.stringContaining("retrying"), "warning");
    await app.start();
    expect(app.modify).toHaveBeenCalledTimes(1);
    expect(app.refresh).toHaveBeenCalledTimes(2);
  });

  test("recovers stale model snapshot across extension reload after refresh failure", async () => {
    const app = setup();
    app.refresh.mockResolvedValueOnce({ aborted: false, errors: new Map([["openai-codex", new Error("refresh failed")]]) });
    await app.start();
    expect(app.stored()).toEqual(source);
    expect(app.getProviderAuthStatus()).toEqual({ configured: false });

    // Simulate /reload: fresh extension closure sharing the same ModelRuntime.
    app.reload();
    await app.start();
    expect(app.refresh).toHaveBeenCalledTimes(2);
    expect(app.getProviderAuthStatus()).toEqual({ configured: true, source: "stored" });

    // Subsequent start sees a configured snapshot and does not refresh again.
    await app.start();
    expect(app.refresh).toHaveBeenCalledTimes(2);
  });

  test("CAS-retrying credential store that aborts its write does not trigger a spurious refresh", async () => {
    const app = setup({ ...source, access: "older-access", refresh: "older-refresh", expires: 1 });
    app.modify.mockImplementationOnce(async (_provider, update) => {
      // First attempt sees stale credential and produces a candidate write;
      await update({ ...source, access: "older-access", refresh: "older-refresh", expires: 1 });
      // Retry sees a concurrently rotated newer credential and skips the write.
      const newer: OAuthCredential = { ...source, access: "rotated-access", refresh: "rotated-refresh", expires: source.expires + 10 };
      const retryResult = await update(newer);
      expect(retryResult).toBeUndefined();
      return newer;
    });
    await app.start();
    expect(app.refresh).not.toHaveBeenCalled();
  });

  test("storage rejection can retry and never echoes error payloads", async () => {
    const app = setup();
    app.modify.mockRejectedValueOnce(new Error("synthetic-secret"));
    await app.start();
    expect(app.refresh).not.toHaveBeenCalled();
    await app.start();
    expect(app.stored()).toEqual(source);
    expect(JSON.stringify(app.notify.mock.calls)).not.toContain("synthetic-secret");
  });

  test("missing bridge warns when UI is available and remains silent in non-UI mode", async () => {
    const uiApp = setup(undefined, true);
    uiApp.ctx.modelRegistry = { refresh: uiApp.refresh } as unknown as ExtensionContext["modelRegistry"];
    await uiApp.start();
    expect(uiApp.modify).not.toHaveBeenCalled();
    expect(uiApp.notify).toHaveBeenCalledWith(expect.stringContaining("does not expose the required credential store"), "warning");

    const headlessApp = setup(undefined, false);
    headlessApp.ctx.modelRegistry = { refresh: headlessApp.refresh } as unknown as ExtensionContext["modelRegistry"];
    await headlessApp.start();
    expect(headlessApp.modify).not.toHaveBeenCalled();
    expect(headlessApp.notify).not.toHaveBeenCalled();
  });

  test("unavailable source performs no writes", async () => {
    vi.mocked(codexAuth).mockResolvedValue([{}, false]);
    const app = setup();
    await app.start();
    expect(app.modify).not.toHaveBeenCalled();
    expect(app.refresh).not.toHaveBeenCalled();
  });
});
