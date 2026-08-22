import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import type {
  ActiveSession,
  ActiveSessionMessage,
  ActiveSessionRegistration,
  ActiveSessionTransport,
  ActiveSessionTransportFactory,
} from "./transport/index.ts";
import { AskRegistry } from "./ask-registry.ts";

function sessionRegistration(ctx: ExtensionContext): ActiveSessionRegistration {
  return {
    name: ctx.sessionManager.getSessionName(),
    cwd: ctx.cwd,
    model: ctx.model?.id ?? "unknown",
    pid: process.pid,
    startedAt: Date.now(),
    lastActivity: Date.now(),
    status: ctx.isIdle() ? "idle" : "thinking",
  };
}

/**
 * Sole owner of mutable lifecycle state:
 * context, transport, connectPromise, generation, subscription cleanups, inbound inbox.
 * Provides generation/epoch validation so a connect that succeeds after shutdown/disconnect
 * is immediately torn down (prevents "revival").
 * On abnormal disconnect, atomically clears pendingInbound and AskRegistry.
 */
export class SessionRuntime {
  context: ExtensionContext | null = null;
  transport: ActiveSessionTransport | null = null;
  connectPromise: Promise<ActiveSessionTransport> | null = null;
  generation = 0;
  transportCleanup: (() => void)[] = [];
  readonly pendingInbound = new Map<string, { from: ActiveSession; message: ActiveSessionMessage }>();
  readonly askRegistry: AskRegistry;

  constructor(
    private readonly pi: ExtensionAPI,
    private readonly createTransport: ActiveSessionTransportFactory,
  ) {
    this.askRegistry = new AskRegistry(() => this.transport);
  }

  setContext(ctx: ExtensionContext | null): void {
    this.context = ctx;
  }

  private readonly handleIncoming = (from: ActiveSession, message: ActiveSessionMessage): void => {
    // First try to resolve a pending ask waiter.
    if (message.replyTo && this.askRegistry.resolveIncoming(message.replyTo, message)) {
      return;
    }

    if (message.expectsReply) {
      this.pendingInbound.set(message.id, { from, message });
    }
    if (!this.context) return;

    const replyHint = message.expectsReply
      ? `\n\nReply with session_message({ action: "reply", replyTo: ${JSON.stringify(message.id)}, message: "..." })`
      : "";
    this.pi.sendMessage(
      {
        customType: "session_message",
        content: `**From ${from.name ?? from.id}** (${from.cwd})${replyHint}\n\n${message.content.text}`,
        display: true,
        details: { from, message },
      },
      { triggerTurn: true, deliverAs: "followUp" },
    );
  };

  private readonly handleCancelled = (messageId: string): void => {
    this.pendingInbound.delete(messageId);
  };

  private onDisconnected(transportInstance: ActiveSessionTransport, error: Error): void {
    // Only act if the disconnected instance is the current transport.
    if (this.transport !== transportInstance) {
      return;
    }
    this.transport = null;
    this.transportCleanup.forEach((cleanup) => cleanup());
    this.transportCleanup = [];
    // Atomic cleanup of inbox and ask waiters.
    this.pendingInbound.clear();
    this.askRegistry.failAll(error);
  }

  async ensureClient(): Promise<ActiveSessionTransport> {
    if (this.transport) return this.transport;
    if (this.connectPromise) return this.connectPromise;
    if (!this.context) throw new Error("Session context is not ready");

    const epoch = this.generation;
    const next = this.createTransport();

    const cleanupMessage = next.onMessage(this.handleIncoming);
    const cleanupCancelled = next.onCancelled(this.handleCancelled);
    const cleanupDisconnected = next.onDisconnected((error) => this.onDisconnected(next, error));
    const nextCleanups = [cleanupMessage, cleanupCancelled, cleanupDisconnected];
    this.transportCleanup = nextCleanups;

    const promise = (async () => {
      try {
        await next.connect(sessionRegistration(this.context!), this.context!.sessionManager.getSessionId());
        // If generation advanced while connecting (shutdown/disconnect), tear down the stale connection immediately.
        if (this.generation !== epoch) {
          nextCleanups.forEach((cleanup) => cleanup());
          if (this.transportCleanup === nextCleanups) {
            this.transportCleanup = [];
          }
          void next.disconnect().catch(() => undefined);
          throw new Error("Session communication disconnected");
        }
        this.transport = next;
        return next;
      } catch (error) {
        nextCleanups.forEach((cleanup) => cleanup());
        if (this.transportCleanup === nextCleanups) {
          this.transportCleanup = [];
        }
        throw error;
      } finally {
        if (this.connectPromise === promise) {
          this.connectPromise = null;
        }
      }
    })();

    this.connectPromise = promise;
    return promise;
  }

  disconnect(): void {
    this.generation += 1;
    // Atomically clear inbox and ask waiters before tearing down transport subscriptions.
    this.pendingInbound.clear();
    this.askRegistry.failAll(new Error("Session communication disconnected"));
    this.transportCleanup.forEach((cleanup) => cleanup());
    this.transportCleanup = [];
    const active = this.transport;
    this.transport = null;
    if (active) {
      void active.disconnect().catch(() => undefined);
    }
    // connectPromise epoch check will handle stale pending connects.
  }
}
