// Builds `mpl.bundle.js`: one IIFE that installs `mpl` inside the QuickJS sandbox.
// Regenerate after changing the pinned `mpl` version: `npm run build:mpl`.
import { rolldown } from "rolldown";
import { fileURLToPath } from "node:url";

const input = fileURLToPath(new URL("./mpl-entry.mjs", import.meta.url));
const file = fileURLToPath(new URL("./mpl.bundle.js", import.meta.url));

// `mpl` imports node:fs/promises only for tracing spans to a file. The sandbox has no
// file system, so replace the module instead of leaving a dynamic import in the bundle.
const stubNodeFs = {
  name: "stub-node-fs",
  resolveId(id) {
    return id === "node:fs/promises" ? "\0stub-node-fs" : null;
  },
  load(id) {
    if (id !== "\0stub-node-fs") return null;
    return "export async function appendFile() { throw new Error('File access is not available in this sandbox.'); }";
  },
};

const build = await rolldown({ input, plugins: [stubNodeFs] });
await build.write({ file, format: "iife", name: "mpl", minify: true });
await build.close();
console.log(`wrote ${file}`);
