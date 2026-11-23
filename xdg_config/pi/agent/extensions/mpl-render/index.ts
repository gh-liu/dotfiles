import { randomBytes } from "node:crypto";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { crc32 } from "node:zlib";
import { colorToHex, type Color } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { CodemodeSandbox, type CodemodeOutputItem } from "@earendil-works/pi-codemode";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

type Limits = { script: number; data: number; pixels: number; png: number; timeoutMs: number; memory: number };

// Upper bounds per call. Tests tighten `limits.timeoutMs` to keep the suite fast.
const limits: Limits = { script: 32_000, data: 256_000, pixels: 4_194_304, png: 8 * 1024 * 1024, timeoutMs: 20_000, memory: 256 * 1024 * 1024 };

const imageSchema = Type.Object({ type: Type.Literal("image"), data: Type.String(), mimeType: Type.Literal("image/png") });

// The extension directory, quoted in the build hint so the message stays correct from any cwd.
const directory = fileURLToPath(new URL(".", import.meta.url));
const readmePath = fileURLToPath(new URL("./README.md", import.meta.url));
const apiDeclarations = join(dirname(createRequire(import.meta.url).resolve("mpl/package.json")), "dist/browser/api.d.ts");

function hexColor(color: Color): string {
  return colorToHex(color);
}

// Escape U+2028/U+2029 so embedded JSON literals remain single-line under JS/QuickJS lexing,
// keeping `firstScriptLine` exact for error stack mapping.
function serializeJsonLiteral(value: unknown): string {
  return JSON.stringify(value).replace(/[\u2028\u2029]/g, (ch) => (ch === "\u2028" ? "\\u2028" : "\\u2029"));
}

// Chart-relevant tokens, in the order a series cycle should try them. Everything else in the theme
// (markdown, syntax, thinking levels, tool boxes) is UI chrome and would crowd a legend.
const paletteTokens = ["accent", "warning", "success", "error", "muted", "text", "userMessageBg", "borderMuted"] as const;

function snapshotPalette(theme: { appearance: "dark" | "light"; colors: Record<string, Color> }) {
  const colors: Record<string, string> = {};
  for (const token of paletteTokens) {
    const color = theme.colors[token];
    // A theme may resolve a token to nothing; omit it instead of passing `undefined` into the sandbox.
    if (color) colors[token] = hexColor(color);
  }
  return { appearance: theme.appearance, colors };
}

// Runs inside an IIFE in the sandbox so internal helpers never enter the caller script's scope.
// Built per call so `limits` stays the only source of truth for the bounds below.
const buildRuntime = (bounds: Limits) => `
const __B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
function __base64(u8) {
  const parts = [];
  let i = 0;
  for (; i + 2 < u8.length; i += 3) {
    const n = (u8[i] << 16) | (u8[i + 1] << 8) | u8[i + 2];
    parts.push(__B64[(n >> 18) & 63] + __B64[(n >> 12) & 63] + __B64[(n >> 6) & 63] + __B64[n & 63]);
  }
  const rest = u8.length - i;
  if (rest === 1) parts.push(__B64[u8[i] >> 2] + __B64[(u8[i] & 3) << 4] + "==");
  else if (rest === 2) parts.push(__B64[u8[i] >> 2] + __B64[((u8[i] & 3) << 4) | (u8[i + 1] >> 4)] + __B64[(u8[i + 1] & 15) << 2] + "=");
  return parts.join("");
}
function render(fig, options) {
  if (!(fig instanceof __Figure)) throw new Error("render(fig) expects the Figure returned by mpl.subplots().");
  const opts = options && typeof options === "object" ? options : {};
  const hasDpi = opts.dpi !== undefined, hasScale = opts.scale !== undefined;
  if (hasDpi && hasScale) throw new Error("Pass either dpi or scale to render(fig); mpl accepts one of them.");
  const scale = hasScale ? opts.scale : 1;
  if (!Number.isInteger(scale) || scale < 1 || scale > 4) throw new Error("scale must be an integer from 1 to 4.");
  const dpi = hasDpi ? opts.dpi : fig.dpi;
  if (!Number.isFinite(dpi) || dpi <= 0) throw new Error("dpi must be a positive number.");
  const width = Math.round(fig.widthIn * dpi * scale);
  const height = Math.round(fig.heightIn * dpi * scale);
  if (!(width > 0 && height > 0)) throw new Error("The figure has no size to render.");
  if (width * height > ${bounds.pixels}) {
    throw new Error("A " + width + "x" + height + " render exceeds the ${bounds.pixels}-pixel limit; reduce figsize, dpi, or scale.");
  }
  const pngOpts = hasDpi ? { ...opts, dpi } : { ...opts, scale };
  const png = __toPNGSync.call(fig, pngOpts);
  if (!(png instanceof Uint8Array)) throw new Error("render(fig) did not produce PNG bytes.");
  if (png.length > ${bounds.png}) throw new Error("The PNG is " + png.length + " bytes; the limit is ${bounds.png}.");
  __image({ type: "image", data: __base64(png), mimeType: "image/png" });
  __text(__renderMarker);
}
`;

// Gives `mpl.subplots()` the theme unless the caller chose a style.
// Plain sandbox code, so no host function crosses the boundary with the colors.
const themedSubplots = `
function __themedRc(colors) {
  const rc = {
    "figure.facecolor": colors.userMessageBg,
    "axes.facecolor": colors.userMessageBg,
    "axes.edgecolor": colors.borderMuted,
    "axes.labelcolor": colors.text,
    "axes.titlecolor": colors.text,
    "text.color": colors.text,
    "xtick.color": colors.muted,
    "ytick.color": colors.muted,
    "grid.color": colors.borderMuted,
    "legend.facecolor": colors.userMessageBg,
    "legend.labelcolor": colors.text,
  };
  for (const key in rc) if (rc[key] === undefined) delete rc[key];
  const cycle = [colors.accent, colors.warning, colors.success, colors.error, colors.muted].filter((color) => color !== undefined);
  if (cycle.length > 1) rc["axes.prop_cycle"] = cycle;
  return rc;
}
if (palette) {
  const __rc = __themedRc(palette.colors);
  const __subplots = mpl.subplots;
  mpl.subplots = function (...args) {
    while (args.length > 0 && args[args.length - 1] === undefined) args.pop();
    const last = args[args.length - 1];
    const isOptions = last !== null && typeof last === "object" && !Array.isArray(last);
    if (isOptions && last.style !== undefined) return __subplots.apply(this, args);
    if (isOptions) args[args.length - 1] = { ...last, rc: { ...__rc, ...last.rc } };
    else args.push({ rc: __rc });
    return __subplots.apply(this, args);
  };
}
`;

let cache: { href: string; source: Promise<string> } | undefined;

// The bundle crosses into the sandbox as a JavaScript string literal, so cache its encoded form.
export function loadBundle(url = new URL("./mpl.bundle.js", import.meta.url)): Promise<string> {
  if (cache?.href === url.href) return cache.source;
  const href = url.href;
  const source = readFile(url, "utf8").then(
    (text) => serializeJsonLiteral(text),
    () => {
      // A newer read may have replaced this entry, even for the same URL.
      if (cache?.source === source) cache = undefined;
      throw new Error(`mpl.bundle.js is missing at ${url.pathname}. Run \`npm run build\` in ${directory}.`);
    },
  );
  cache = { href, source };
  return source;
}

const PNG_SIGNATURE = Buffer.from("89504e470d0a1a0a", "hex");
const BASE64_PATTERN = /^[A-Za-z0-9+/]+={0,2}$/;

// Valid PNG bit depths per color type (ISO/IEC 15948, Table 11.1).
const PNG_BIT_DEPTHS: Readonly<Record<number, readonly number[]>> = {
  0: [1, 2, 4, 8, 16],
  2: [8, 16],
  3: [1, 2, 4, 8],
  4: [8, 16],
  6: [8, 16],
};

function validatePng(data: string, bounds: Pick<Limits, "png" | "pixels"> = limits): Buffer {
  if (typeof data !== "string" || data.length === 0 || data.length % 4 !== 0) {
    throw new Error("The script produced invalid base64 image data.");
  }
  const padding = data.endsWith("==") ? 2 : data.endsWith("=") ? 1 : 0;
  const decodedLength = (data.length / 4) * 3 - padding;
  if (decodedLength > bounds.png) {
    throw new Error(`The PNG is ${decodedLength} bytes; the limit is ${bounds.png}.`);
  }
  if (!BASE64_PATTERN.test(data)) {
    throw new Error("The script produced invalid base64 image data.");
  }

  const bytes = Buffer.from(data, "base64");
  if (bytes.length < 8 || !bytes.subarray(0, 8).equals(PNG_SIGNATURE)) {
    throw new Error("The script produced data that is not a PNG.");
  }
  // Signature (8) + IHDR length (4) + type (4) + data (13) + CRC (4) = 33 bytes minimum.
  if (bytes.length < 33) {
    throw new Error("The script produced a truncated PNG.");
  }
  const ihdrLength = bytes.readUInt32BE(8);
  const ihdrType = bytes.subarray(12, 16).toString("ascii");
  if (ihdrType !== "IHDR" || ihdrLength !== 13) {
    throw new Error("The script produced an invalid PNG header.");
  }

  const width = bytes.readUInt32BE(16);
  const height = bytes.readUInt32BE(20);
  if (width === 0 || height === 0) {
    throw new Error("The PNG has zero width or height.");
  }
  if (width * height > bounds.pixels) {
    throw new Error("The PNG exceeds the rendered-pixel limit.");
  }

  const bitDepth = bytes[24];
  const colorType = bytes[25];
  const compression = bytes[26];
  const filter = bytes[27];
  const interlace = bytes[28];
  const allowedDepths = PNG_BIT_DEPTHS[colorType];
  if (!allowedDepths || !allowedDepths.includes(bitDepth) || compression !== 0 || filter !== 0 || (interlace !== 0 && interlace !== 1)) {
    throw new Error("The script produced an invalid PNG header.");
  }

  let offset = 8;
  let hasIdat = false;
  let hasIend = false;
  let hasPlte = false;
  while (offset < bytes.length) {
    if (offset + 12 > bytes.length) {
      throw new Error("The script produced a truncated PNG.");
    }
    const chunkLength = bytes.readUInt32BE(offset);
    if (chunkLength > 0x7fffffff || offset + 12 + chunkLength > bytes.length) {
      throw new Error("The script produced a truncated PNG.");
    }
    const typeStart = offset + 4;
    const dataEnd = offset + 8 + chunkLength;
    const expectedCrc = bytes.readUInt32BE(dataEnd);
    if (crc32(bytes.subarray(typeStart, dataEnd)) !== expectedCrc) {
      throw new Error("The script produced a corrupted PNG.");
    }
    const type = bytes.subarray(typeStart, typeStart + 4).toString("ascii");
    if (offset > 8 && type === "IHDR") {
      throw new Error("The script produced an invalid PNG header.");
    }
    if (type === "IDAT" && chunkLength > 0) {
      hasIdat = true;
    } else if (type === "PLTE") {
      if (chunkLength === 0 || chunkLength % 3 !== 0 || chunkLength > 256 * 3) {
        throw new Error("The script produced an invalid PNG.");
      }
      hasPlte = true;
    } else if (type === "IEND") {
      if (chunkLength !== 0 || dataEnd + 4 !== bytes.length) {
        throw new Error("The script produced a corrupted PNG.");
      }
      hasIend = true;
    }
    offset = dataEnd + 4;
  }

  if (colorType === 3 && !hasPlte) {
    throw new Error("The script produced an invalid PNG.");
  }
  if (!hasIdat || !hasIend) {
    throw new Error("The script produced an incomplete PNG.");
  }
  return bytes;
}

function collectLogs(output: readonly CodemodeOutputItem[], marker = "", maxChars = 2_000): string {
  const parts: string[] = [];
  let length = 0;
  let seen = false;
  for (const item of output) {
    if (length >= maxChars) break;
    if (item.type !== "text") continue;
    if (marker && !item.console && item.text === marker) continue;
    if (seen) {
      parts.push("\n");
      length += 1;
      if (length >= maxChars) break;
    }
    seen = true;
    const remaining = maxChars - length;
    if (item.text.length <= remaining) {
      parts.push(item.text);
      length += item.text.length;
    } else {
      parts.push(item.text.slice(0, remaining));
      length = maxChars;
      break;
    }
  }
  return parts.join("");
}

function findRenderedImage(output: readonly CodemodeOutputItem[], marker: string): Extract<CodemodeOutputItem, { type: "image" }> | undefined {
  for (let i = output.length - 1; i >= 1; i--) {
    const item = output[i];
    if (item.type === "text" && !item.console && item.text === marker) {
      const prev = output[i - 1];
      if (prev.type === "image") return prev;
    }
  }
  return undefined;
}

export const mplRender = defineTool({
  name: "mpl_render",
  label: "Render chart",
  exposure: "deferred",
  description: `Render a PNG chart from native mpl code in QuickJS. Scope: \`mpl\`, \`data\` (JSON, default null), \`palette\`, and \`render(fig)\` (required; optional \`{ scale?: 1..4, dpi? }\`). Show with \`image((await tools.mpl_render({ script, data })).image)\`.

- API: \`mpl.subplots({ figsize, dpi, sharex, sharey, style, rc })\`; positional args first, kwargs in trailing object; do not call \`toPNG*\`.
- Theme & sizing: Charts follow the current Pi theme by default; explicit \`style\` hands color control back to mpl, and \`rc\` overrides theme keys. \`palette\` (\`{ appearance, colors }\`, e.g. \`palette.colors.accent\`) is null without a UI. Keep \`figsize\` compact (\`[6, 3.6]\`-\`[9.5, 4.2]\`) with \`scale: 2\`.
- Limits & docs: ${limits.script}c script, ${limits.data}c data, ${limits.pixels}px, ${limits.png}B PNG, ${limits.timeoutMs / 1000}s. Read ${readmePath} and ${apiDeclarations} for details.`,
  parameters: Type.Object({
    script: Type.String({ description: "Async function body using `mpl`, `data`, and `palette`; call render(fig)." }),
    data: Type.Optional(Type.Unknown({ description: "JSON passed to the script as `data`." })),
  }),
  outputSchema: Type.Object({ image: imageSchema, logs: Type.Optional(Type.String()) }),
  async execute(_id, { script, data }, signal, _onUpdate, ctx) {
    if (script.length > limits.script) throw new Error(`script must be at most ${limits.script} characters; split the work or generate data in code.`);
    const dataJson = serializeJsonLiteral(data ?? null);
    if (dataJson.length > limits.data) throw new Error(`data must be at most ${limits.data} characters of JSON; sample or aggregate it first.`);

    const palette = ctx.hasUI ? snapshotPalette(ctx.ui.theme) : null;
    const bundle = await loadBundle();
    const renderMarker = `__mpl_render_${randomBytes(16).toString("hex")}`;
    const preamble = [
      `const data = ${dataJson};`,
      `const palette = ${serializeJsonLiteral(palette)};`,
      `const { mpl, render } = ((__bundle, __renderMarker) => {`,
      `const __image = image;`,
      `const __text = text;`,
      `const mpl = new Function(__bundle + "\\nreturn mpl;")();`,
      `const __Figure = mpl.Figure;`,
      `const __toPNGSync = __Figure.prototype.toPNGSync;`,
      buildRuntime(limits),
      themedSubplots,
      `return { mpl, render };`,
      `})(${bundle}, ${serializeJsonLiteral(renderMarker)});\n`,
    ].join("\n");
    const firstScriptLine = preamble.split("\n").length;

    const sandbox = new CodemodeSandbox({ timeoutMs: limits.timeoutMs, memoryLimitBytes: limits.memory });
    let result;
    try {
      result = await sandbox.execute(`${preamble}${script}`, { signal });
    } finally {
      await sandbox.close();
    }
    const logs = collectLogs(result.output, renderMarker);
    if (!result.ok) {
      const where = new RegExp("codemode\\.js:(\\d+):(\\d+)", "g");
      const stack = (result.error.stack ?? "").replace(where, (frame, line: string, column: string) => {
        const n = Number(line);
        return n >= firstScriptLine ? `script:${n - firstScriptLine + 1}:${column}` : frame;
      });
      const detail = stack || `${result.error.name ?? "Error"}: ${result.error.message}`;
      const reason = result.error.kind === "timeout"
        ? `Chart script exceeded ${limits.timeoutMs / 1000}s.`
        : result.error.kind === "aborted"
          ? "Chart script was cancelled."
          : `Chart script failed: ${detail}`;
      throw new Error(logs ? `${reason}\nScript output:\n${logs}` : reason);
    }

    const block = findRenderedImage(result.output, renderMarker);
    if (!block) throw new Error("The script did not call render(fig).");
    validatePng(block.data, limits);

    const image = { type: "image", data: block.data, mimeType: "image/png" } as const;
    const content = logs ? [image, { type: "text" as const, text: logs }] : [image];
    const structuredContent: Record<string, string | typeof image> = logs ? { image, logs } : { image };
    return { content, structuredContent, details: undefined };
  },
});

export default function (pi: ExtensionAPI) {
  pi.registerTool(mplRender);
}

export { collectLogs, limits, validatePng };
