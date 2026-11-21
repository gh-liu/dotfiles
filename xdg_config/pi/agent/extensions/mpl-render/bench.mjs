// Renders one chart twice: through the sandboxed tool, then with plain Node `mpl`.
// The PNGs must be byte-identical; timings show the QuickJS overhead per call.
import { mplRender } from "./index.ts";
import * as mpl from "mpl";
import { allFonts } from "mpl/fonts/all";

const data = {
  dates: ["2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04", "2026-10-05"],
  p95: [120, 183, 146, 171, 159],
  qps: [12, 18, 21],
};

const script = `const [fig, ax] = mpl.subplots(1, 2, { figsize: [9, 4.2], style: "pro-dark", gridspec_kw: { width_ratios: [2.2, 1] } });
ax[0].plot(data.dates.map((d) => new Date(d + "T00:00:00Z")), data.p95, { label: "p95" });
ax[0].axhline(175, { ls: "--", label: "SLO" });
ax[0].set_ylabel("ms");
ax[0].legend();
ax[1].barh(["api", "db", "cache"], data.qps, { height: 0.55 });
render(fig, { scale: 2 });`;

const times = [];
let sandboxed;
for (let i = 0; i < 3; i++) {
  const started = performance.now();
  const result = await mplRender.execute("bench", { script, data }, undefined, undefined, {});
  times.push(Math.round(performance.now() - started));
  sandboxed = Buffer.from(result.structuredContent.image.data, "base64");
}

mpl.registerFonts(...allFonts);
const [fig, ax] = mpl.subplots(1, 2, { figsize: [9, 4.2], style: "pro-dark", gridspec_kw: { width_ratios: [2.2, 1] } });
ax[0].plot(data.dates.map((d) => new Date(d + "T00:00:00Z")), data.p95, { label: "p95" });
ax[0].axhline(175, { ls: "--", label: "SLO" });
ax[0].set_ylabel("ms");
ax[0].legend();
ax[1].barh(["api", "db", "cache"], data.qps, { height: 0.55 });
const native = Buffer.from(fig.toPNGSync({ scale: 2 }));

const identical = sandboxed.equals(native);
console.log("sandboxed ms:", times.join(" "));
console.log("png bytes:", sandboxed.length, "identical to Node mpl:", identical);
process.exitCode = identical ? 0 : 1;
