import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { fileURLToPath, pathToFileURL } from "node:url";
import { expect, test } from "vitest";
import type { ExtensionToolContext } from "@earendil-works/pi-coding-agent";
import { limits, loadBundle, mplRender } from "./index.ts";

function render(params: Parameters<typeof mplRender.execute>[1]) {
  return mplRender.execute("test", params, undefined, undefined, {} as ExtensionToolContext);
}

/** A PNG header with arbitrary IHDR dimensions: enough for the host-side checks, not decodable. */
function header(width: number, height: number) {
  const ihdr = Buffer.alloc(25);
  ihdr.writeUInt32BE(13, 0);
  ihdr.write("IHDR", 4, "ascii");
  ihdr.writeUInt32BE(width, 8);
  ihdr.writeUInt32BE(height, 12);
  ihdr[16] = 8;
  ihdr[17] = 2;
  return Buffer.concat([Buffer.from("89504e470d0a1a0a", "hex"), ihdr]);
}

async function withLimits<T>(patch: Partial<typeof limits>, body: () => Promise<T>): Promise<T> {
  const saved = { ...limits };
  Object.assign(limits, patch);
  try {
    return await body();
  } finally {
    Object.assign(limits, saved);
  }
}

test("uses the live pixel limit inside the sandbox, before allocating pixels", async () => {
  await withLimits({ pixels: 100_000 }, async () => {
    await expect(render({ script: `const [fig] = mpl.subplots({ figsize: [4, 3] }); render(fig);` }))
      .rejects.toThrow("A 400x300 render exceeds the 100000-pixel limit");
  });
});

test("uses the live PNG limit inside the sandbox, before base64 encoding", async () => {
  await withLimits({ png: 1_000 }, async () => {
    await expect(render({ script: `const [fig, ax] = mpl.subplots(); ax.plot([1, 2], [1, 2]); render(fig);` }))
      .rejects.toThrow(/The PNG is \d+ bytes; the limit is 1000\./);
  });
});

test("rejects an oversized PNG on the host even when a script bypasses render()", async () => {
  await withLimits({ png: 32 }, async () => {
    const bytes = header(1, 1);
    await expect(render({ script: `image({ type: "image", data: "${bytes.toString("base64")}", mimeType: "image/png" });` }))
      .rejects.toThrow("The PNG is 33 bytes; the limit is 32.");
  });
});

test("accepts exactly the script and data limits and rejects one character more", { timeout: 60_000 }, async () => {
  const call = "const [fig] = mpl.subplots(); render(fig);";
  const pad = `/*${"x".repeat(32_000 - call.length - 5)}*/\n`;
  expect(pad.length + call.length).toBe(32_000);
  await expect(render({ script: pad + call })).resolves.toMatchObject({ structuredContent: { image: { mimeType: "image/png" } } });
  await expect(render({ script: `${pad} ${call}` })).rejects.toThrow("script must be at most 32000 characters");

  const data = { blob: "x".repeat(256_000 - 11) };
  expect(JSON.stringify(data).length).toBe(256_000);
  await expect(render({ data, script: call })).resolves.toMatchObject({ structuredContent: { image: { mimeType: "image/png" } } });
  await expect(render({ data: { blob: `${data.blob}x` }, script: call })).rejects.toThrow("data must be at most 256000 characters");
});

test("binds an omitted data argument as null and has no palette outside a UI", async () => {
  await expect(render({ script: `if (data !== null || palette !== null) throw new Error(typeof data + "|" + typeof palette);\nconst [fig] = mpl.subplots(); render(fig);` }))
    .resolves.toMatchObject({ structuredContent: { image: { mimeType: "image/png" } } });
});

test("registers every shipped colormap in the sandbox", async () => {
  await expect(render({ script: `const [fig, ax] = mpl.subplots(); ax.imshow([[0, 1], [1, 0]], { cmap: "plasma" }); render(fig);` }))
    .resolves.toMatchObject({ structuredContent: { image: { mimeType: "image/png" } } });
});

test("accepts the scale boundaries and rejects dpi or scale outside their ranges", async () => {
  const atFour = await render({ script: `const [fig] = mpl.subplots({ figsize: [2, 1.5] }); render(fig, { scale: 4 });` });
  const png = Buffer.from((atFour.structuredContent as { image: { data: string } }).image.data, "base64");
  expect([png.readUInt32BE(16), png.readUInt32BE(20)]).toEqual([800, 600]);
  await expect(render({ script: `const [fig] = mpl.subplots(); render(fig, { scale: 0 });` }))
    .rejects.toThrow("scale must be an integer from 1 to 4");
  await expect(render({ script: `const [fig] = mpl.subplots(); render(fig, { dpi: 0 });` }))
    .rejects.toThrow("dpi must be a positive number");
});

test("retries a bundle read after a failure instead of caching the rejection", async () => {
  const dir = await mkdtemp(join(tmpdir(), "mpl-bundle-"));
  const file = join(dir, "bundle.js");
  const url = pathToFileURL(file);
  const directory = fileURLToPath(new URL(".", import.meta.url));
  try {
    await expect(loadBundle(url)).rejects.toThrow("Run `npm run build` in " + directory);
    await writeFile(file, "var mpl = {};\n");
    await expect(loadBundle(url)).resolves.toBe(JSON.stringify("var mpl = {};\n"));
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("keeps essential constraints inline and links local README and API declarations", () => {
  const readme = fileURLToPath(new URL("./README.md", import.meta.url));
  const declarations = join(dirname(createRequire(import.meta.url).resolve("mpl/package.json")), "dist/browser/api.d.ts");
  expect(mplRender.description).toContain(readme);
  expect(mplRender.description).toContain(declarations);
  expect(mplRender.description).toContain("palette.colors.accent");
  expect(mplRender.description).toContain("Charts follow the current Pi theme by default");
  expect(mplRender.description).toContain("hands color control back to mpl");
  expect(mplRender.description).not.toContain("theme.rc");
  expect(mplRender.description).toContain("render(fig)");
  expect(mplRender.description).toContain("subplots");
  expect(mplRender.exposure).toBe("deferred");
  expect(JSON.stringify(mplRender.outputSchema)).toContain('"image"');
  expect(JSON.stringify(mplRender.outputSchema)).toContain('"logs"');
});
