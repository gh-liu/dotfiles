import { expect, test } from "vitest";
import type { ExtensionToolContext } from "@earendil-works/pi-coding-agent";
import { mplRender } from "./index.ts";

function execute(script: string, data?: unknown) {
  return mplRender.execute("smoke", { script, data }, undefined, undefined, {} as ExtensionToolContext);
}

function pngDimensions(result: Awaited<ReturnType<typeof execute>>) {
  const image = (result.structuredContent as { image: { data: string; mimeType: string } }).image;
  expect(image.mimeType).toBe("image/png");
  const bytes = Buffer.from(image.data, "base64");
  expect(bytes.subarray(0, 8).toString("hex")).toBe("89504e470d0a1a0a");
  return [bytes.readUInt32BE(16), bytes.readUInt32BE(20)];
}

test("returns console logs alongside the image on success and omits them when empty", async () => {
  const withLogs = await execute(`
    console.log("rendered", 42);
    const [fig, ax] = mpl.subplots({ figsize: [3, 2] });
    ax.plot([0, 1], [0, 1]);
    render(fig);
  `);
  expect(withLogs.structuredContent).toMatchObject({
    image: { mimeType: "image/png" },
    logs: "rendered 42",
  });
  expect(withLogs.content).toHaveLength(2);
  expect(withLogs.content[1]).toEqual({ type: "text", text: "rendered 42" });

  const withoutLogs = await execute(`
    const [fig, ax] = mpl.subplots({ figsize: [3, 2] });
    ax.plot([0, 1], [0, 1]);
    render(fig);
  `);
  expect(withoutLogs.content).toHaveLength(1);
  expect((withoutLogs.structuredContent as { logs?: string }).logs).toBeUndefined();

  const truncated = await execute(`
    console.log("x".repeat(2_500));
    const [fig, ax] = mpl.subplots({ figsize: [3, 2] });
    ax.plot([0, 1], [0, 1]);
    render(fig);
  `);
  expect((truncated.structuredContent as { logs?: string }).logs).toHaveLength(2_000);
});

test("supports lines, reference lines, step, and decimation", async () => {
  const xs = Array.from({ length: 5000 }, (_, i) => i / 100);
  const ys = xs.map((x) => Math.sin(x));
  const result = await execute(`
    const [fig, ax] = mpl.subplots({ figsize: [6, 3.6] });
    ax.plot([0, 1, 2, 3], [1, 3, 2, 4], "--o", { label: "fmt", lw: 1.5, ms: 4 });
    ax.plot([0, 1, 2, 3], [2, 2.5, 1.5, 3.5], { drawstyle: "steps-mid", label: "drawstyle" });
    ax.step([0, 1, 2, 3], [0.5, 1.2, 0.8, 1.9], { where: "post", label: "step" });
    ax.plot(data.xs, data.ys, { decimate: 1, alpha: 0.4, label: "decimated" });
    ax.axhline(2.5, { ls: ":" });
    ax.axvline(1.5, { ls: "--" });
    ax.axline([0, 0], { slope: 0.8 });
    ax.hlines([1, 3], 0.2, 2.8, { alpha: 0.5 });
    ax.vlines([0.5, 2.5], 0.5, 3.5, { alpha: 0.5 });
    ax.legend({ loc: "upper left" });
    render(fig, { scale: 2 });
  `, { xs, ys });
  expect(pngDimensions(result)).toEqual([1200, 720]);
});

test("supports statistical plots: hist, boxplot, bar, errorbar, and fill_between", async () => {
  const result = await execute(`
    const [fig, axs] = mpl.subplots(2, 2, { figsize: [8.5, 5.0] });
    const [n, bins, patches] = axs[0][0].hist(
      [[1, 2, 2, 3, 3, 3, 4], [2, 3, 3, 4, 4, 5]],
      { bins: 5, histtype: "barstacked", density: true, rwidth: 0.85, align: "mid" },
    );
    if (!Array.isArray(n) || n.length !== 2 || !bins || bins.length !== 6 || !Array.isArray(patches) || patches.length !== 2) {
      throw new Error("unexpected hist return shape");
    }
    axs[0][1].boxplot([[1, 2, 3, 4, 5], [2, 4, 4, 5, 7]], {
      patch_artist: true,
      notch: true,
      showmeans: true,
      meanline: true,
      tick_labels: ["A", "B"],
    });
    axs[1][0].bar(["x", "y", "z"], [3, 5, 4], { width: 0.5, bottom: 0.5 });
    axs[1][0].errorbar([0, 1, 2], [3.5, 5.5, 4.5], {
      yerr: [[0.3, 0.4, 0.2], [0.5, 0.6, 0.4]],
      capsize: 3,
      barsabove: true,
      lolims: true,
      errorevery: 1,
      elinestyle: "--",
      fmt: "none",
    });
    axs[1][1].fill_between([0, 1, 2, 3], [1, 2, 1.5, 2.5], [2, 3.2, 2.8, 3.8], { alpha: 0.35 });
    fig.tight_layout();
    render(fig);
  `);
  expect(pngDimensions(result)).toEqual([850, 500]);
});

test("supports imshow norms, scatter, spans, and horizontal/vertical colorbars", async () => {
  const result = await execute(`
    const nx = 40, ny = 30, zLog = [], zSigned = [];
    for (let j = 0; j < ny; j++) {
      const r1 = [], r2 = [];
      for (let i = 0; i < nx; i++) {
        const u = i / (nx - 1), v = j / (ny - 1);
        r1.push(Math.pow(10, -1 + 3 * u) * (0.5 + v));
        r2.push(u - v);
      }
      zLog.push(r1);
      zSigned.push(r2);
    }
    const [fig, axs] = mpl.subplots(1, 2, { figsize: [9.0, 4.0] });
    const im1 = axs[0].imshow(zLog, { cmap: "viridis", norm: "log", origin: "lower", interpolation: "bilinear" });
    fig.colorbar(im1, { ax: axs[0], orientation: "horizontal", location: "bottom", extend: "both", label: "log" });
    axs[0].axvspan(10, 20, { alpha: 0.15 });
    const im2 = axs[1].imshow(zSigned, {
      cmap: "coolwarm",
      norm: { kind: "twoslope", vmin: -1, vcenter: 0, vmax: 1 },
      origin: "lower",
    });
    fig.colorbar(im2, { ax: axs[1], location: "right", extend: "min", shrink: 0.85, label: "signed" });
    axs[1].scatter([5, 15, 25], [5, 15, 25], { s: [30, 60, 90], c: [0.2, 0.5, 0.9], cmap: "plasma", edgecolors: "#ffffff" });
    fig.tight_layout();
    render(fig);
  `);
  expect(pngDimensions(result)).toEqual([900, 400]);
});

test("supports text, annotations, figure titles, and pie charts", async () => {
  const result = await execute(`
    const [fig, axs] = mpl.subplots(1, 2, { figsize: [8.5, 3.8] });
    axs[0].plot([0, 1, 2], [1, 3, 2]);
    axs[0].text(0.05, 0.9, "panel A", { transform: axs[0].transAxes });
    axs[0].annotate("peak", [1, 3], {
      xytext: [0.45, 0.72],
      xycoords: "data",
      textcoords: "axes fraction",
      arrowprops: { arrowstyle: "->", connectionstyle: "arc3,rad=0.2" },
    });
    axs[0].set_title("Left title", { loc: "left" });

    const pie = axs[1].pie([35, 25, 20, 20], {
      labels: ["A", "B", "C", "D"],
      autopct: (pct) => pct.toFixed(0) + "%",
      explode: [0.08, 0, 0, 0],
      wedgeprops: { width: 0.45 },
      startangle: 90,
    });
    if (!pie.wedges || pie.wedges.length !== 4) throw new Error("unexpected pie result");
    fig.suptitle("Overview");
    fig.supxlabel("x");
    fig.supylabel("y");
    fig.tight_layout();
    render(fig);
  `);
  expect(pngDimensions(result)).toEqual([850, 380]);
});

test("supports log/date/categorical axes, spines, twinx, and sync export formats", async () => {
  const result = await execute(`
    const [fig, axs] = mpl.subplots(1, 2, { figsize: [9.0, 3.8], gridspec_kw: { wspace: 0.4 } });
    const dates = [new Date("2026-01-01T00:00:00Z"), new Date("2026-02-01T00:00:00Z"), new Date("2026-03-01T00:00:00Z")];
    axs[0].plot(dates, [10, 100, 1000]);
    axs[0].set_yscale("log");
    axs[0].xaxis.set_major_locator(new mpl.MonthLocator());
    axs[0].xaxis.set_major_formatter(new mpl.DateFormatter("%b"));
    axs[0].grid(true, { which: "both", alpha: 0.3 });
    axs[0].tick_params({ which: "major", direction: "in" });
    const right = axs[0].twinx();
    right.plot(dates, [1, 2, 3], { ls: "--" });
    right.set_ylabel("ratio");

    axs[1].bar(["alpha", "beta", "gamma"], [4, 2, 5]);
    axs[1].invert_yaxis();
    axs[1].set_anchor([0.5, 0.5]);
    axs[1].spines.top.set_visible(false);
    axs[1].spines.right.set_visible(false);
    axs[1].spines.left.set_linewidth(1.5);

    const svg = fig.toSVG({ precision: 2, idPrefix: "smoke" });
    if (!svg.includes("smoke")) throw new Error("idPrefix missing in SVG");
    if ([...fig.svgChunks({ precision: 2, idPrefix: "smoke" })].join("") !== svg) throw new Error("svgChunks mismatch");

    const rgba1 = fig.toRGBA();
    const rgba2 = fig.toRGBA({ out: rgba1 });
    if (rgba1.px !== rgba2.px) throw new Error("toRGBA out buffer was not reused");

    const png = fig.toPNGSync();
    if (png[0] !== 0x89 || png[1] !== 0x50 || png[2] !== 0x4e || png[3] !== 0x47) {
      throw new Error("bad PNG magic from toPNGSync");
    }
    fig.tight_layout();
    render(fig);
  `);
  expect(pngDimensions(result)).toEqual([900, 380]);
});

test("enforces documented sandbox and mpl API constraints", async () => {
  await execute(`
    const expectThrow = (name, fn) => {
      let threw = false;
      try { fn(); } catch { threw = true; }
      if (!threw) throw new Error("expected throw: " + name);
    };
    const [fig, ax] = mpl.subplots({ figsize: [3, 2] });
    expectThrow("bicubic interpolation", () => ax.imshow([[1, 2], [3, 4]], { interpolation: "bicubic" }));
    expectThrow("compass anchor", () => ax.set_anchor("NE"));
    expectThrow("twoslope without vcenter", () => ax.imshow([[1, 2], [3, 4]], { norm: { kind: "twoslope", vmin: 0, vmax: 1 } }));
    expectThrow("requireColormap missing", () => mpl.requireColormap("definitely-not-a-cmap"));
    expectThrow("interactive svg without sidecar", () => fig.toSVG({ interactive: true }));

    const missing = mpl.getColormap("definitely-not-a-cmap");
    if (missing.ok !== false) throw new Error("expected getColormap missing result");

    if (typeof CompressionStream !== "undefined" || typeof ReadableStream !== "undefined" || typeof TextEncoder !== "undefined" || typeof TextDecoder !== "undefined") {
      throw new Error("unexpected Web Stream/encoding globals in QuickJS");
    }

    ax.plot([0, 1], [0, 1]);
    render(fig);
  `);
});
