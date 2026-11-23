import { crc32, deflateSync } from "node:zlib";
import type { Color } from "@earendil-works/pi-tui";
import { expect, test, vi } from "vitest";
import * as mpl from "mpl";
import { allFonts } from "mpl/fonts/all";
import type { CodemodeOutputItem } from "@earendil-works/pi-codemode";
import type { ExtensionToolContext } from "@earendil-works/pi-coding-agent";
import { collectLogs, limits, loadBundle, mplRender, validatePng } from "./index.ts";

function render(params: Parameters<typeof mplRender.execute>[1], signal?: AbortSignal) {
  return mplRender.execute("test", params, signal, undefined, {} as ExtensionToolContext);
}

const chart = `render((() => {
  const [fig, ax] = mpl.subplots(1, 2, { figsize: [9, 4.2], style: "pro-dark", gridspec_kw: { width_ratios: [2.2, 1] } });
  ax[0].plot(data.dates.map((d) => new Date(d)), data.p95, { label: "p95" });
  ax[0].axhline(175, { ls: "--", label: "SLO" });
  ax[0].legend();
  ax[1].barh(["api", "db", "cache"], data.qps, { height: 0.55 });
  return fig;
})()${", { scale: 2 }"});`;

const dates = ["2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04", "2026-10-05"];
const data = { dates, p95: [120, 183, 146, 171, 159], qps: [12, 18, 21] };

const PNG_SIG = Buffer.from("89504e470d0a1a0a", "hex");

function pngChunk(type: string, payload: Buffer) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(payload.length, 0);
  const body = Buffer.concat([Buffer.from(type, "ascii"), payload]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body), 0);
  return Buffer.concat([len, body, crc]);
}

/** A PNG header with arbitrary IHDR dimensions: lacks CRC, IDAT, and IEND (not decodable). */
function header(width: number, height: number) {
  const ihdr = Buffer.alloc(25);
  ihdr.writeUInt32BE(13, 0);
  ihdr.write("IHDR", 4, "ascii");
  ihdr.writeUInt32BE(width, 8);
  ihdr.writeUInt32BE(height, 12);
  ihdr[16] = 8;
  ihdr[17] = 2;
  return Buffer.concat([PNG_SIG, ihdr]);
}

function minimalPng(width = 1, height = 1, colorType = 6) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = colorType;
  const bpp = colorType === 6 ? 4 : colorType === 2 ? 3 : 1;
  const idat = deflateSync(Buffer.alloc((width * bpp + 1) * height));
  const chunks = [pngChunk("IHDR", ihdr)];
  if (colorType === 3) chunks.push(pngChunk("PLTE", Buffer.from([0, 0, 0])));
  chunks.push(pngChunk("IDAT", idat), pngChunk("IEND", Buffer.alloc(0)));
  return Buffer.concat([PNG_SIG, ...chunks]);
}

test("renders native mpl code byte-identically to Node mpl", async () => {
  const result = await render({ data, script: chart });
  expect(mplRender.exposure).toBe("direct");
  const image = (result.structuredContent as { image: { data: string; mimeType: string } }).image;
  expect(result.content).toEqual([image]);
  expect(image.mimeType).toBe("image/png");

  mpl.registerFonts(...allFonts);
  const [fig, ax] = mpl.subplots(1, 2, { figsize: [9, 4.2], style: "pro-dark", gridspec_kw: { width_ratios: [2.2, 1] } });
  ax[0].plot(dates.map((d) => new Date(d)), data.p95, { label: "p95" });
  ax[0].axhline(175, { ls: "--", label: "SLO" });
  ax[0].legend();
  ax[1].barh(["api", "db", "cache"], data.qps, { height: 0.55 });
  expect(image.data).toBe(Buffer.from(fig.toPNGSync({ scale: 2 })).toString("base64"));

  const png = Buffer.from(image.data, "base64");
  expect([png.readUInt32BE(16), png.readUInt32BE(20)]).toEqual([1800, 840]);
});

test("renders at an explicit dpi and rejects dpi together with scale", async () => {
  const atDpi = await render({ script: `const [fig] = mpl.subplots({ figsize: [4, 3] }); render(fig, { dpi: 200 });` });
  const png = Buffer.from((atDpi.structuredContent as { image: { data: string } }).image.data, "base64");
  expect([png.readUInt32BE(16), png.readUInt32BE(20)]).toEqual([800, 600]);
  await expect(render({ script: `const [fig] = mpl.subplots(); render(fig, { dpi: 200, scale: 2 });` }))
    .rejects.toThrow("Pass either dpi or scale");
});

test("passes artist references to fig.colorbar and requires a render() call", async () => {
  const result = await render({
    data: { matrix: [[1, 3, 5], [4, 8, 12], [2, 6, 9]] },
    script: `const [fig, ax] = mpl.subplots();
      const heat = ax.imshow(data.matrix);
      fig.colorbar(heat, { ax, label: "ms" });
      render(fig);`,
  });
  expect(result.structuredContent).toMatchObject({ image: { mimeType: "image/png" } });
  await expect(render({ script: `const [fig] = mpl.subplots(); return 1;` }))
    .rejects.toThrow("did not call render(fig)");
});

const themeColors = {
  accent: { kind: "rgb", r: 185, g: 140, b: 255 },
  warning: { kind: "rgb", r: 232, g: 224, b: 107 },
  success: { kind: "rgb", r: 110, g: 231, b: 168 },
  error: { kind: "rgb", r: 255, g: 138, b: 122 },
  muted: { kind: "rgb", r: 168, g: 173, b: 192 },
  text: { kind: "rgb", r: 230, g: 231, b: 236 },
  borderMuted: { kind: "rgb", r: 138, g: 146, b: 181 },
  userMessageBg: { kind: "rgb", r: 58, g: 63, b: 92 },
} satisfies Record<string, Color>;

/** What the extension is expected to derive from `themeColors`; rendering validates the rc keys. */
const themedRc = {
  "figure.facecolor": "#3a3f5c",
  "axes.facecolor": "#3a3f5c",
  "axes.edgecolor": "#8a92b5",
  "axes.labelcolor": "#e6e7ec",
  "axes.titlecolor": "#e6e7ec",
  "text.color": "#e6e7ec",
  "xtick.color": "#a8adc0",
  "ytick.color": "#a8adc0",
  "grid.color": "#8a92b5",
  "legend.facecolor": "#3a3f5c",
  "legend.labelcolor": "#e6e7ec",
  "axes.prop_cycle": ["#b98cff", "#e8e06b", "#6ee7a8", "#ff8a7a", "#a8adc0"],
} as const;

const themeContext = { hasUI: true, ui: { theme: { appearance: "dark", colors: themeColors } } } as unknown as ExtensionToolContext;

const pngOf = (result: { structuredContent?: unknown }) =>
  Buffer.from((result.structuredContent as { image: { data: string } }).image.data, "base64");

const uiRender = (params: Parameters<typeof mplRender.execute>[1]) => mplRender.execute("test", params, undefined, undefined, themeContext);

test("themes mpl.subplots with the UI palette by default", async () => {
  const script = `const [fig, ax] = mpl.subplots({ figsize: [2, 1.5] });\nax.plot([0, 1, 2], [1, 3, 2], { label: "a" });\nax.legend();\nrender(fig);`;
  const themed = await uiRender({ script });
  // The same figure with the expected rc spelled out proves both the mapping and that it applied.
  const explicit = await render({ data: { rc: themedRc }, script: `const [fig, ax] = mpl.subplots({ figsize: [2, 1.5], rc: data.rc });\nax.plot([0, 1, 2], [1, 3, 2], { label: "a" });\nax.legend();\nrender(fig);` });
  expect(pngOf(themed).equals(pngOf(explicit))).toBe(true);
  expect(pngOf(themed).equals(pngOf(await render({ script })))).toBe(false);
});

test("hands color control back to mpl when the script passes a style", async () => {
  const script = `const [fig, ax] = mpl.subplots({ figsize: [2, 1.5], style: "pro-dark" });\nax.plot([0, 1], [0, 1]);\nrender(fig);`;
  expect(pngOf(await uiRender({ script })).equals(pngOf(await render({ script })))).toBe(true);
});

test("keeps explicit rc keys above the theme", async () => {
  const override = { "axes.facecolor": "#ff0000", "axes.prop_cycle": ["#00ff00"] };
  const ui = await uiRender({ script: `const [fig, ax] = mpl.subplots({ figsize: [2, 1.5], rc: data.rc });\nax.plot([0, 1, 2], [1, 3, 2]);\nrender(fig);`, data: { rc: override } });
  const explicit = await render({
    data: { rc: { ...themedRc, ...override } },
    script: `const [fig, ax] = mpl.subplots({ figsize: [2, 1.5], rc: data.rc });\nax.plot([0, 1, 2], [1, 3, 2]);\nrender(fig);`,
  });
  expect(pngOf(ui).equals(pngOf(explicit))).toBe(true);
});

test("passes only chart-relevant tokens as hex strings", async () => {
  const context = {
    hasUI: true,
    ui: {
      theme: {
        appearance: "light",
        colors: {
          accent: { kind: "rgb", r: 255, g: 128, b: 0 },
          text: { kind: "oklch", l: 0.9, c: 0.02, h: 250 },
          dim: { kind: "indexed", index: 8 },
          mdHeading: { kind: "rgb", r: 1, g: 2, b: 3 },
        } satisfies Record<string, Color>,
      },
    },
  } as unknown as ExtensionToolContext;
  await mplRender.execute("test", {
    script: `if (typeof palette.colors.accent !== "string") throw new Error("host color leaked");\nif ("dim" in palette.colors || "mdHeading" in palette.colors) throw new Error("palette included chrome: " + Object.keys(palette.colors));\nif (palette.appearance !== "light") throw new Error(palette.appearance);\nconst [fig, ax] = mpl.subplots({ figsize: [2, 1.5] });\nax.plot([1, 2], [1, 2], { color: palette.colors.accent });\nrender(fig);`,
  }, undefined, undefined, context);
});

test("hides host globals and internal helpers, and maps script line numbers", async () => {
  await expect(render({
    data: { sep: "a\u2028b\u2029c" },
    script: `const [fig] = mpl.subplots();\nrender(fig, { scale: process.pid });`,
  })).rejects.toThrow(/process is not defined\n.*at <anonymous> \(script:2:\d+\)/s);
  await expect(render({
    script: `throw new Error([typeof require, typeof fetch, typeof Buffer, typeof __bundle, typeof __B64, typeof __base64, typeof __themedRc, typeof __renderMarker, typeof __image, typeof __text, typeof __Figure, typeof __toPNGSync].join("|"));`,
  })).rejects.toThrow("undefined|undefined|undefined|undefined|undefined|undefined|undefined|undefined|undefined|undefined|undefined|undefined");
  await expect(render({ script: `const [fig, ax] = mpl.subplots();\nrender(ax);` }))
    .rejects.toThrow("render(fig) expects the Figure");
});

test("reports console output when a script fails", async () => {
  await expect(render({ script: `console.log("debug", 1);\nthrow new Error("nope");` }))
    .rejects.toThrow(/Chart script failed: Error: nope[\s\S]*Script output:\ndebug 1/);
});

test("ignores direct image() calls and requires output from render(fig)", async () => {
  const fake = header(1, 1).toString("base64");
  // Direct image() without render(fig) must be rejected, even with PNG header bytes.
  await expect(render({ script: `image({ type: "image", data: "${fake}", mimeType: "image/png" });` }))
    .rejects.toThrow("did not call render(fig)");

  // Direct image() after render(fig) must not replace the rendered chart.
  const expected = await render({ script: `const [fig, ax] = mpl.subplots({ figsize: [2, 1.5] }); ax.plot([0, 1], [0, 1]); render(fig);` });
  const withTrailingImage = await render({
    script: `const [fig, ax] = mpl.subplots({ figsize: [2, 1.5] });
      ax.plot([0, 1], [0, 1]);
      render(fig);
      image({ type: "image", data: "${fake}", mimeType: "image/png" });`,
  });
  expect(pngOf(withTrailingImage).equals(pngOf(expected))).toBe(true);

  // Overriding fig.toPNGSync on the instance must not hijack render(fig).
  const tampered = await render({
    data: { fake: Array.from(header(1, 1)) },
    script: `const [fig, ax] = mpl.subplots({ figsize: [2, 1.5] });
      ax.plot([0, 1], [0, 1]);
      fig.toPNGSync = () => new Uint8Array(data.fake);
      render(fig);`,
  });
  expect(pngOf(tampered).equals(pngOf(expected))).toBe(true);

  // Direct image() with a structurally valid PNG must still be rejected without render(fig).
  await expect(render({ script: `image({ type: "image", data: "${minimalPng().toString("base64")}", mimeType: "image/png" });` }))
    .rejects.toThrow("did not call render(fig)");

  // render.toString() must not leak any internal marker, and logs/errors must not include it.
  const logged = await render({
    script: `const [fig, ax] = mpl.subplots({ figsize: [2, 1.5] });
      ax.plot([0, 1], [0, 1]);
      console.log("hello");
      render(fig);
      if (/__mpl_render_[0-9a-f]{32}/.test(render.toString())) throw new Error("marker leaked in render.toString()");`,
  });
  expect((logged.structuredContent as { logs?: string }).logs).toBe("hello");

  await expect(render({
    script: `const [fig, ax] = mpl.subplots({ figsize: [2, 1.5] });
      ax.plot([0, 1], [0, 1]);
      console.log("before crash");
      render(fig);
      throw new Error("boom");`,
  })).rejects.not.toThrow(/__mpl_render_/);
});

test("validates base64 bounds and complete PNG structure on the host side", () => {
  const valid = minimalPng();
  expect(validatePng(valid.toString("base64")).equals(valid)).toBe(true);
  expect(validatePng(minimalPng(2, 2, 3).toString("base64")).length).toBeGreaterThan(0);

  // Rejects malformed base64 and oversized payloads before allocating a decoded Buffer.
  expect(() => validatePng("not-padded")).toThrow("invalid base64");
  expect(() => validatePng("!!!!")).toThrow("invalid base64");
  const huge = "A".repeat(4 * 1024);
  const fromSpy = vi.spyOn(Buffer, "from");
  try {
    expect(() => validatePng(huge, { png: 100, pixels: limits.pixels })).toThrow("The PNG is 3072 bytes; the limit is 100.");
    expect(fromSpy).not.toHaveBeenCalled();
  } finally {
    fromSpy.mockRestore();
  }

  expect(() => validatePng(Buffer.from("not a png").toString("base64"))).toThrow("not a PNG");
  expect(() => validatePng(PNG_SIG.toString("base64"))).toThrow("truncated PNG");

  const badChunk = header(10, 10);
  badChunk.write("NOPE", 12, "ascii");
  expect(() => validatePng(badChunk.toString("base64"))).toThrow("invalid PNG header");
  expect(() => validatePng(header(0, 10).toString("base64"))).toThrow("zero width or height");
  expect(() => validatePng(header(3000, 3000).toString("base64"))).toThrow("exceeds the rendered-pixel limit");

  // Header-only bytes without valid CRC / IDAT / IEND must be rejected.
  expect(() => validatePng(header(1, 1).toString("base64"))).toThrow("corrupted PNG");

  const ihdrPayload = Buffer.alloc(13);
  ihdrPayload.writeUInt32BE(1, 0);
  ihdrPayload.writeUInt32BE(1, 4);
  ihdrPayload[8] = 8;
  ihdrPayload[9] = 6;
  const ihdrOnly = Buffer.concat([PNG_SIG, pngChunk("IHDR", ihdrPayload)]);
  expect(() => validatePng(ihdrOnly.toString("base64"))).toThrow("incomplete PNG");

  const noIdat = Buffer.concat([PNG_SIG, pngChunk("IHDR", ihdrPayload), pngChunk("IEND", Buffer.alloc(0))]);
  expect(() => validatePng(noIdat.toString("base64"))).toThrow("incomplete PNG");

  const badCrc = Buffer.from(valid);
  badCrc[badCrc.length - 1] ^= 0xff;
  expect(() => validatePng(badCrc.toString("base64"))).toThrow("corrupted PNG");

  const trailing = Buffer.concat([valid, Buffer.from([0x00])]);
  expect(() => validatePng(trailing.toString("base64"))).toThrow("corrupted PNG");

  const indexedNoPltePayload = Buffer.from(ihdrPayload);
  indexedNoPltePayload[9] = 3;
  const indexedNoPlte = Buffer.concat([
    PNG_SIG,
    pngChunk("IHDR", indexedNoPltePayload),
    pngChunk("IDAT", deflateSync(Buffer.alloc(2))),
    pngChunk("IEND", Buffer.alloc(0)),
  ]);
  expect(() => validatePng(indexedNoPlte.toString("base64"))).toThrow("invalid PNG");
});

test("truncates logs incrementally to 2000 chars and strips the internal render marker", async () => {
  const marker = "__mpl_render_0123456789abcdef0123456789abcdef";
  let reads = 0;
  const tailItem: CodemodeOutputItem = {
    type: "text",
    get text() {
      reads += 1;
      return "should not be read";
    },
  };
  const output: CodemodeOutputItem[] = [
    { type: "text", text: marker },
    { type: "text", text: "a".repeat(1_999), console: true },
    { type: "text", text: "bcde", console: true },
    tailItem,
  ];
  expect(collectLogs(output, marker)).toBe(`${"a".repeat(1_999)}\n`);
  expect(reads).toBe(0);

  // Exact boundary: 2000-char item followed by more items has no trailing newline and skips the tail.
  let exactReads = 0;
  const exactTail: CodemodeOutputItem = {
    type: "text",
    get text() {
      exactReads += 1;
      return "y";
    },
  };
  expect(collectLogs([
    { type: "text", text: "x".repeat(2_000), console: true },
    exactTail,
  ], marker)).toBe("x".repeat(2_000));
  expect(exactReads).toBe(0);

  // Console log matching the marker text is kept (only non-console internal markers are stripped).
  expect(collectLogs([{ type: "text", text: marker, console: true }], marker)).toBe(marker);

  // End-to-end cap via the tool.
  const res = await render({
    script: `for (let i = 0; i < 300; i++) console.log("line-" + i + "-" + "x".repeat(20));
      const [fig, ax] = mpl.subplots({ figsize: [2, 1.5] });
      ax.plot([0, 1], [0, 1]);
      render(fig);`,
  });
  const logs = (res.structuredContent as { logs?: string }).logs ?? "";
  expect(logs.length).toBe(2_000);
  expect(logs.startsWith("line-0-")).toBe(true);
});

test("strips trailing undefined arguments before injecting theme rc in mpl.subplots", async () => {
  const withTrailingUndefined = await uiRender({
    script: `const [fig, ax] = mpl.subplots(undefined);\nax.plot([0, 1], [0, 1]);\nrender(fig);`,
  });
  const plain = await uiRender({
    script: `const [fig, ax] = mpl.subplots();\nax.plot([0, 1], [0, 1]);\nrender(fig);`,
  });
  expect(pngOf(withTrailingUndefined).equals(pngOf(plain))).toBe(true);
});

test("stops runaway scripts, memory growth, and oversized renders", { timeout: 90_000 }, async () => {
  const deadline = limits.timeoutMs;
  limits.timeoutMs = 1_000;
  try {
    await expect(render({ script: `while (true) {}` })).rejects.toThrow("exceeded 1s");
  } finally {
    limits.timeoutMs = deadline;
  }
  await expect(render({ script: `const kept = []; while (true) kept.push(new Array(1 << 20).fill(0));` }))
    .rejects.toThrow(/out of memory/);
  await expect(render({ script: `const [fig] = mpl.subplots(1, 1, { figsize: [60, 60] }); render(fig);` }))
    .rejects.toThrow("exceeds the 4194304-pixel limit");
  await expect(render({ script: `const [fig] = mpl.subplots(); render(fig, { scale: 5 });` }))
    .rejects.toThrow("scale must be an integer from 1 to 4");
});

test("cancels a running script when the caller aborts", async () => {
  const controller = new AbortController();
  setTimeout(() => controller.abort(new Error("stop")), 300);
  await expect(render({ script: `while (true) {}` }, controller.signal)).rejects.toThrow("Chart script was cancelled");
});

test("rejects oversized inputs and a missing bundle before starting a sandbox", async () => {
  await expect(render({ script: "x".repeat(32_001) })).rejects.toThrow("script must be at most 32000 characters");
  await expect(render({ script: "render();", data: { blob: "x".repeat(300_000) } })).rejects.toThrow("data must be at most 256000 characters");
  await expect(loadBundle(new URL("./missing.bundle.js", import.meta.url))).rejects.toThrow("mpl.bundle.js is missing");
});
