import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { createLocalIpcTransport } from "./messaging/transport/local-ipc.ts";
import type { ActiveSessionTransportFactory } from "./messaging/transport/index.ts";
import { registerSessionsTool } from "./history/index.ts";
import type { ActiveSessionsProvider } from "./history/index.ts";
import { registerSessionMessageTool } from "./messaging/index.ts";
import { SessionRuntime } from "./messaging/runtime.ts";

export type SessionsExtensionOptions = {
  createTransport?: ActiveSessionTransportFactory;
};

/**
 * Thin entry point: composes SessionRuntime + the two capability tools and forwards lifecycle events.
 * All mutable state (context, transport, generation, pendingInbound, askRegistry)
 * lives in SessionRuntime; each capability folder owns its tool end-to-end and only
 * orchestrates via its own modules (the sessions tool receives IPC through an injected provider).
 */
export default function sessionsExtension(pi: ExtensionAPI, options: SessionsExtensionOptions = {}): void {
  const createTransport = options.createTransport ?? createLocalIpcTransport;
  const runtime = new SessionRuntime(pi, createTransport);

  const listActiveSessions: ActiveSessionsProvider = async () => {
    const transport = await runtime.ensureClient();
    return { sessions: await transport.listSessions(), currentId: transport.sessionId };
  };

  registerSessionsTool(pi, listActiveSessions);
  registerSessionMessageTool(pi, runtime);

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
