import { crc32, deflateSync } from "node:zlib";
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

function chunk(type: string, data: Buffer) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body), 0);
  return Buffer.concat([len, body, crc]);
}

function png(width: number, height: number) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = 6;
  const idat = deflateSync(Buffer.alloc((width * 4 + 1) * height));
  const bytes = Buffer.concat([
    Buffer.from("89504e470d0a1a0a", "hex"),
    chunk("IHDR", ihdr),
    chunk("IDAT", idat),
    chunk("IEND", Buffer.alloc(0)),
  ]);
  return { type: "image" as const, data: bytes.toString("base64"), mimeType: "image/png" };
}

const run = (script: string) => mplRender.execute("test", { script }, undefined, undefined, {} as ExtensionToolContext);

test("closes the sandbox after a successful call and passes the documented caps", async () => {
  state.closes = 0;
  state.options.length = 0;
  state.execute = async (code: string) => {
    const marker = code.match(/__mpl_render_[0-9a-f]{32}/)?.[0];
    if (!marker) throw new Error("missing render marker in preamble");
    return {
      ok: true,
      value: undefined,
      output: [png(1, 1), { type: "text", text: marker }],
      calls: [],
      storeWrites: { set: {}, delete: [] },
    };
  };
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
