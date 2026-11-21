import { expect, test, vi } from "vitest";
import type { ExtensionToolContext } from "@earendil-works/pi-coding-agent";

// The sandbox is replaced here on purpose: the invariant under test is that a worker is
// always closed, including when `execute()` itself throws, which a real sandbox cannot be
// made to do without breaking production code.
const state = vi.hoisted(() => ({
  closes: 0,
  options: [] as unknown[],
  execute: (async (_code: string) => ({}) as unknown) as (code: string) => Promise<unknown>,
}));

vi.mock("@earendil-works/pi-codemode", () => ({
  CodemodeSandbox: class {
    constructor(options: unknown) {
      state.options.push(options);
    }
    execute(code: string) {
      return state.execute(code);
    }
    async close() {
      state.closes += 1;
    }
  },
}));

const { mplRender } = await import("./index.ts");

function png(width: number, height: number) {
  const ihdr = Buffer.alloc(25);
  ihdr.writeUInt32BE(13, 0);
  ihdr.write("IHDR", 4, "ascii");
  ihdr.writeUInt32BE(width, 8);
  ihdr.writeUInt32BE(height, 12);
  const bytes = Buffer.concat([Buffer.from("89504e470d0a1a0a", "hex"), ihdr]);
  return { type: "image", data: bytes.toString("base64"), mimeType: "image/png" };
}

const run = (script: string) => mplRender.execute("test", { script }, undefined, undefined, {} as ExtensionToolContext);

test("closes the sandbox after a successful call and passes the documented caps", async () => {
  state.closes = 0;
  state.options.length = 0;
  state.execute = async () => ({ ok: true, value: undefined, output: [png(1, 1)], calls: [], storeWrites: { set: {}, delete: [] } });
  const result = await run("render(fig);");
  expect(state.closes).toBe(1);
  expect(state.options).toEqual([{ timeoutMs: 20_000, memoryLimitBytes: 256 * 1024 * 1024 }]);
  expect(result.structuredContent).toMatchObject({ image: { mimeType: "image/png" } });
});

test("closes the sandbox when execute() throws", async () => {
  state.closes = 0;
  state.execute = async () => {
    throw new Error("worker failed");
  };
  await expect(run("render(fig);")).rejects.toThrow("worker failed");
  expect(state.closes).toBe(1);
});
