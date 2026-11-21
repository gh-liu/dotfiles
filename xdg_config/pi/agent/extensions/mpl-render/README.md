# mpl-render for Pi

`tools.mpl_render({ script, data })` runs native [mpl](https://github.com/ivarvong/mpl) code and returns a PNG. Use it from Pi codemode. Pass the returned `image` to `image()` to show it inline on supported terminals and get a temporary PNG path in the tool output.

## Install

From this directory, run `npm ci` with Node.js 24 or newer. Do not use `--ignore-scripts`: the pinned GitHub dependency `mpl` builds during installation, and this folder's `postinstall` bundles it for the sandbox (see [The bundle is not committed](#the-bundle-is-not-committed)). With codemode enabled, restart Pi or run `/reload` to load the extension.

## Use

```js
const { image: chart } = await tools.mpl_render({
  data: { days: ["2026-10-01", "2026-10-02", "2026-10-03"], p95: [120, 183, 146] },
  script: `const [fig, ax] = mpl.subplots();
    ax.plot(data.days.map((d) => new Date(d + "T00:00:00Z")), data.p95, { label: "p95" });
    ax.axhline(175, { ls: "--", label: "SLO" });
    ax.set_ylabel("ms");
    ax.legend();
    render(fig);`,
});
image(chart);
```

The script is the body of an async function, so top-level `await` and `return` work. It sees four things of its own:

- `mpl` — the full mpl API, with every shipped font and colormap registered. Not a subset and not a proxy: `fig.colorbar(ax.imshow(...), { ax })` and any other method work as they do in Node.
- `data` — your JSON, parsed inside the sandbox. Defaults to `null`.
- `palette` — the current Pi theme as hex strings, or `null` when the tool runs without a UI. Charts follow the theme by default: `mpl.subplots()` is themed (panel-colored surfaces, theme text, tick and grid colors, and a series cycle from the accent and status colors), so a script that never mentions colors still matches the terminal. An explicit `style` hands color control back to mpl, and explicit `rc` keys override the theme. `palette.appearance` is `"dark"` or `"light"`. `palette.colors` carries the chart-relevant tokens — `accent`, `warning`, `success`, `error`, `muted`, `text`, `userMessageBg`, `borderMuted` — for explicit choices such as `ax.plot(x, y, { color: palette.colors.accent })`. Pi has no terminal-background token; `userMessageBg` is the tinted panel color, dark in dark themes and light in light ones. A theme may omit a token, in which case that key is absent. mpl's `style` option (`"pro-dark"`, `"pro-mono"`, …) is a bundled stylesheet, not Pi's theme. The sandbox receives only strings, not the host theme object.
- `render(fig, options?)` — the way to produce the image. It validates the figure, enforces the pixel and PNG limits, and attaches the PNG to the tool result. `options` reach `fig.toPNGSync()`: pass `scale` (integer 1–4) or `dpi`, not both, so `render(fig, { scale: 2 })` and `render(fig, { dpi: 200 })` both work. Setting `dpi` on the figure instead (`mpl.subplots({ figsize, dpi })`) and calling `render(fig)` is equivalent.

### mpl API and terminal sizing

`mpl` mirrors matplotlib's object-oriented API: positional arguments come first, followed by keyword arguments in a trailing object (`ax.plot(x, y, { color: "C1", lw: 2 })`). Unknown keywords throw an error rather than being silently ignored.

- **Figure**: `const [fig, ax] = mpl.subplots({ style, rc, figsize, dpi })`; `subplots(nrows, ncols, { sharex, sharey, squeeze, gridspec_kw })` returns `Axes`, `Axes[]`, or `Axes[][]`; also `tight_layout()`, `suptitle()`, and `colorbar(artist, { ax, label })`.
- **Axes**: `plot`, `scatter`, `bar`, `barh`, `hist`, `errorbar`, `imshow`, `text`, `annotate`, `twinx`, `axhline`, `axvline`, plus `set_title`, `set_xlabel`, `set_ylabel`, `set_xlim`, `set_ylim`, `set_xscale`, `set_yscale`, `grid`, `legend`, and `tick_params`.
- **Inline preview sizing**: charts are viewed inline in the terminal (scaled to 60–120 cells wide), so keep `figsize` compact — `[6, 3.6]`–`[7, 4.2]` for a single plot, `[8.5, 3.8]`–`[9.5, 4.2]` for two side-by-side panels (avoid >2 side-by-side columns) — and use `render(fig, { scale: 2 })` or `dpi: 150`–`200` for crisp text rather than enlarging `figsize`.
- **References**: the tool description gives the absolute path to this file and the installed `dist/browser/api.d.ts` matching the pinned `mpl` version. Read the local declarations first; see mpl's upstream [guide](https://github.com/ivarvong/mpl/blob/main/docs/guide.md) (examples, styles, `rc`) and [API reference](https://github.com/ivarvong/mpl/blob/main/docs/api.md) for behavior that the declarations do not explain.

Codemode's own script globals are also present (`tools` is empty, `store`/`load` last only for the call, and `image()` is what `render()` uses internally). `console.log` / `text()` output (up to 2,000 characters) is returned in `logs` (and alongside the image) on success as well as on failure.

Everything else is absent: no `process`, `require`, `fetch`, timers, file system, network, module loading, Web Streams (`ReadableStream`, `CompressionStream`), or `TextEncoder`/`TextDecoder`.

## Sandbox & API Notes

### Sandbox export limitations

- **Sync-only export**: `CompressionStream`, `ReadableStream`, `TextEncoder`, and `TextDecoder` are not available in QuickJS. Always use `render(fig, { scale: 2 })` (which calls `toPNGSync()`), or synchronous `toPNGSync()`, `toSVG()`, `svgChunks()`, and `toRGBA()`. Do not call `toPNG()`, `pngStream()`, or `svgStream()`.
- **`toSVG({ interactive: true })`**: requires `mpl.registerSidecar(...)` first; otherwise it throws.

### Differences from Python matplotlib

- **`imshow` `interpolation`**: supports only `'nearest'`, `'none'`, `'antialiased'`, `'auto'`, `'hanning'`, and `'bilinear'`. `'bicubic'` and `'lanczos'` throw.
- **`ax.set_anchor`**: accepts only `'C'` or `[x, y]` (for example `ax.set_anchor([0.8, 0.9])`); compass strings such as `'NE'` throw.
- **`norm`**: pass `'log'`, `'linear'`, or `{ kind: 'twoslope', vmin, vcenter, vmax }` (`twoslope` requires `vcenter`), rather than `new mpl.LogNorm()`.
- **`getColormap` vs `requireColormap`**: `mpl.getColormap(name)` returns `{ ok, error }` when missing instead of throwing; use `mpl.requireColormap(name)` when you want an exception listing available colormaps.
- **`DateFormatter` / `ConciseDateFormatter`**: attaching them to numeric or categorical axes does not throw at runtime; only attach them to `Date[]` axes.
- **`axis.scale`**: holds a Scale instance object rather than a `'log'` string.

### Theme & layout best practices

- **5-color cycle**: the default themed `axes.prop_cycle` contains 5 colors (`accent`, `warning`, `success`, `error`, `muted`), wrapping at `C5+`. Pass explicit `color` values or sample a `cmap` when plotting more than 5 series.
- **`twinx()` spacing**: in multi-column figures with `twinx()`, increase `gridspec_kw.wspace` (for example `>= 0.35`) or call `fig.tight_layout()` so the right-hand y-axis label does not collide with the adjacent subplot.
- **Compatible `sharex` / `sharey`**: do not share axes across incompatible types (such as numeric vs. categorical axes), or categorical ticks will overwrite numeric ones.
- **Multiline labels & annotations**: call `fig.tight_layout()` (or `subplots_adjust()`) when using multiline axis labels or colorbars, and keep `transAxes` text away from `legend` corners.
- **Overlaying `imshow()`**: a second `imshow()` with a smaller `extent` updates the axes `viewLim`; call `ax.set_xlim()` and `ax.set_ylim()` afterwards if you want to lock the combined bounds.

## Limits

| Limit           | Value                               |
|-----------------|-------------------------------------|
| `script`        | 32,000 characters                   |
| `data`          | 256,000 characters of JSON          |
| Rendered pixels | 4,194,304 (for example 2048 × 2048) |
| PNG size        | 8 MiB                               |
| Wall clock      | 20 seconds                          |
| Sandbox heap    | 256 MiB                             |

The deadline and heap are enforced by the QuickJS sandbox (`CodemodeSandbox` from `@earendil-works/pi-codemode`, also used by the built-in `codemode` tool): a script that loops or allocates forever fails with `exceeded 20s` or `out of memory` instead of blocking Pi. Aborting the tool call stops the script too, reported as `Chart script was cancelled.` Script errors report the caller's line numbers as `script:<line>:<column>`, and the script's `console` output when it failed.

Limits are checked twice for the paths they cover: `render()` rejects an oversized figure before allocating pixels, and the host re-checks the PNG header and size so a script that calls `image()` directly cannot bypass them.

## How it works

`bundle.mjs` bundles `mpl` plus every font into `mpl.bundle.js`, one minified IIFE (1.4 MB, about 170 ms to parse in QuickJS). On each call the extension builds a script:

```js
const __bundle = "<the IIFE>";
var mpl = new Function(__bundle + "\nreturn mpl;")();
/* render() and base64 helpers */
const data = {/* your JSON */};
const palette = {/* the current theme, or null */};
/* your script */
```

and hands it to `CodemodeSandbox` from `@earendil-works/pi-codemode`. That class runs a `worker_threads` worker per call with a fresh QuickJS/WASM VM, a shared interrupt flag, and `worker.terminate()` on deadline or abort. Pi's extension host never evaluates model-written code; only the PNG crosses back.

## Verified

`node mpl-render/bench.mjs` runs a two-panel latency chart through the tool and then through plain Node `mpl`:

```text
sandboxed ms: 402 360 360
png bytes: 59231 identical to Node mpl: true
```

Measurements on an Apple M-series laptop, 1.4 MB minified bundle, `figsize: [9, 4.2]`, `scale: 2`:

| Step | Time |
| --- | --- |
| Worker + VM startup | ~20 ms |
| Evaluating the bundle in QuickJS | ~170 ms |
| Drawing + PNG encode at 1800 × 840 | ~150 ms |
| Full call | 360–400 ms |

The sandbox produces byte-identical PNGs to Node `mpl`, so native scripts are not a reduced rendering path. `npm test` in this directory (typecheck plus this folder's tests) asserts that identity, the `dpi` and `scale` paths, script line mapping, host-side image validation, cancellation, and the snapshot limits. Failure modes were checked with real scripts: `while (true) {}` fails at the deadline, an unbounded `Array` allocation fails with `out of memory`, a 60 × 60 inch figure fails the pixel limit before rendering, and `process.pid` raises `ReferenceError` with a mapped script line.

## The bundle is not committed

`mpl.bundle.js` (1.4 MB) is a build artifact: it is git-ignored and produced locally from the pinned `mpl` dependency by this folder's `postinstall` script. This folder is its own package (`pi-mpl-render`) with its own `package.json` and `package-lock.json`. `npm ci` here installs those dependencies and runs that `postinstall`. `rolldown` is a regular dependency here for that reason, so an install without dev dependencies still builds it. Only `--ignore-scripts` skips it, and then the first call fails with the command to run:

```sh
npm run build
```
