import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerSessionsTool } from "./history/index.ts";

/** Register the session-history search and entry-reading capability. */
export default function sessionsExtension(pi: ExtensionAPI): void {
  registerSessionsTool(pi);
}
