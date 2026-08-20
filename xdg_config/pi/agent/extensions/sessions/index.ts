import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { createLocalIpcTransport } from "./transport/local-ipc.ts";
import type { ActiveSessionTransportFactory } from "./transport/index.ts";
import { SessionRuntime } from "./session-runtime.ts";
import { registerSessionsTools } from "./tools.ts";

export type SessionsExtensionOptions = {
  createTransport?: ActiveSessionTransportFactory;
};

/**
 * Thin entry point: composes SessionRuntime + tools and forwards lifecycle events.
 * All mutable state (context, transport, generation, pendingInbound, askRegistry)
 * lives in SessionRuntime; tools only orchestrate via runtime/history.
 */
export default function sessionsExtension(pi: ExtensionAPI, options: SessionsExtensionOptions = {}): void {
  const createTransport = options.createTransport ?? createLocalIpcTransport;
  const runtime = new SessionRuntime(pi, createTransport);

  registerSessionsTools(pi, runtime);

  pi.on("session_start", (_event, ctx) => {
    runtime.setContext(ctx);
    void runtime.ensureClient().catch(() => {
      // History search remains available when local IPC is unavailable.
    });
  });

  pi.on("session_shutdown", () => {
    runtime.disconnect();
    runtime.setContext(null);
  });
}
