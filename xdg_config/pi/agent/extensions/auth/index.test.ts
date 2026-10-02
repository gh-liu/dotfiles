import { beforeEach, describe, expect, test, vi } from "vitest";
import type { Credential, OAuthCredential } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import extension from "./index.ts";
import { codexAuth } from "./codex-auth.ts";

vi.mock("./codex-auth.ts", () => ({ codexAuth: vi.fn() }));
const source: OAuthCredential = { type: "oauth", access: "synthetic-access", refresh: "synthetic-refresh", accountId: "account", expires: 4_000_000_000_000 };

function setup(current?: Credential, hasUI = true) {
  let stored = current;
  let handler!: (event: unknown, ctx: ExtensionContext) => Promise<void>;
  const modify = vi.fn(async (_provider: string, update: (value: Credential | undefined) => Promise<Credential | undefined>) => {
    const next = await update(stored);
    if (next) stored = next;
    return stored;
  });
  const refresh = vi.fn(async () => ({ errors: new Map<string, Error>() }));
  const notify = vi.fn();
  const ctx = { hasUI, ui: { notify }, modelRegistry: { runtime: { credentials: { modify } }, refresh } } as unknown as ExtensionContext;
  extension({ on: (_event: string, callback: typeof handler) => { handler = callback; } } as unknown as ExtensionAPI);
  return { start: () => handler({}, ctx), ctx, modify, refresh, notify, stored: () => stored };
}

beforeEach(() => vi.mocked(codexAuth).mockReset().mockReturnValue([source, true]));

describe("Codex credential synchronization", () => {
  test("does not read secrets during factory loading; imports at session start and refreshes offline", async () => {
    const app = setup();
    expect(codexAuth).not.toHaveBeenCalled();
    await app.start();
    expect(app.stored()).toEqual(source);
    expect(app.refresh).toHaveBeenCalledWith({ allowNetwork: false, providers: ["openai-codex"] });
  });

  test.each([
    { ...source, expires: source.expires + 1 },
    { ...source, access: "rotated", refresh: "rotated", expires: source.expires },
    { ...source, accountId: "different", expires: 1 },
    { type: "api_key" as const, key: "synthetic-key" },
    { ...source, expires: NaN },
  ])("preserves newer, equal, different-account, API-key or unknown-age credentials", async (current) => {
    const app = setup(current);
    await app.start();
    expect(app.stored()).toEqual(current);
    expect(app.refresh).not.toHaveBeenCalled();
  });

  test("updates older same-account OAuth without losing provider metadata", async () => {
    const app = setup({ ...source, expires: 1, metadata: "keep" });
    await app.start();
    expect(app.stored()).toEqual({ ...source, metadata: "keep" });
  });

  test("checks latest store state and reads a fresh source at each session boundary", async () => {
    const app = setup();
    await app.start();
    vi.mocked(codexAuth).mockReturnValue([{ ...source, expires: source.expires + 1 }, true]);
    await app.start();
    expect(app.stored()).toMatchObject({ expires: source.expires + 1 });
    expect(app.refresh).toHaveBeenCalledTimes(2);
  });

  test("an expired source may bootstrap missing auth but cannot replace existing auth", async () => {
    vi.mocked(codexAuth).mockReturnValue([{ ...source, expires: 2 }, true]);
    const existing = setup({ ...source, expires: 1 });
    await existing.start();
    expect(existing.stored()).toMatchObject({ expires: 1 });
    const missing = setup();
    await missing.start();
    expect(missing.stored()).toMatchObject({ expires: 2 });
  });

  test("coalesces overlapping session starts", async () => {
    const app = setup();
    await Promise.all([app.start(), app.start()]);
    expect(app.modify).toHaveBeenCalledTimes(1);
    expect(app.refresh).toHaveBeenCalledTimes(1);
  });

  test("refresh failure retries only refresh, not a successful write, without leaking errors", async () => {
    const app = setup();
    app.refresh.mockResolvedValueOnce({ errors: new Map([["openai-codex", new Error("synthetic-secret")]]) });
    await app.start();
    await app.start();
    expect(app.modify).toHaveBeenCalledTimes(1);
    expect(app.refresh).toHaveBeenCalledTimes(2);
    expect(JSON.stringify(app.notify.mock.calls)).not.toContain("synthetic-secret");
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

  test("missing bridge fails safely; non-UI mode remains silent", async () => {
    const app = setup(undefined, false);
    app.ctx.modelRegistry = { refresh: app.refresh } as unknown as ExtensionContext["modelRegistry"];
    await app.start();
    expect(app.modify).not.toHaveBeenCalled();
    expect(app.notify).not.toHaveBeenCalled();
  });

  test("unavailable source performs no writes", async () => {
    vi.mocked(codexAuth).mockReturnValue([{}, false]);
    const app = setup();
    await app.start();
    expect(app.modify).not.toHaveBeenCalled();
    expect(app.refresh).not.toHaveBeenCalled();
  });
});
