import type { ActiveSessionMessage, ActiveSessionTransport } from "./transport/index.ts";

type AskEntry = {
  messageId: string;
  resolve: (message: ActiveSessionMessage) => void;
  reject: (error: Error) => void;
  timer: NodeJS.Timeout;
  signal: AbortSignal;
  abortHandler: () => void;
  cleanup: () => void;
  sent: boolean;
};

/**
 * Manages concurrent ask waiters keyed by messageId.
 * Unified termination path: first clear timer/abort listener, delete map entry,
 * then optionally cancelAsk if the message was already sent.
 */
export class AskRegistry {
  private readonly entries = new Map<string, AskEntry>();

  constructor(private readonly transportProvider: () => ActiveSessionTransport | null) {}

  get size(): number {
    return this.entries.size;
  }

  has(messageId: string): boolean {
    return this.entries.has(messageId);
  }

  /**
   * Create a pending ask waiter. Returns a promise that resolves with the reply.
   * Registers timeout and abort handlers that will reject and optionally cancelAsk.
   */
  create(messageId: string, timeoutMs: number, signal: AbortSignal): Promise<ActiveSessionMessage> {
    if (this.entries.has(messageId)) {
      throw new Error(`Ask already pending for ${messageId}`);
    }

    let resolve!: (message: ActiveSessionMessage) => void;
    let reject!: (error: Error) => void;
    const promise = new Promise<ActiveSessionMessage>((res, rej) => {
      resolve = res;
      reject = rej;
    });

    // Use a mutable holder so timer/abort handlers can access the entry after insertion.
    const entry: Partial<AskEntry> = {
      messageId,
      resolve,
      reject,
      signal,
      sent: false,
    } as Partial<AskEntry>;

    const timer = setTimeout(() => {
      const current = this.entries.get(messageId);
      if (!current) return;
      // Timeout always attempts to cancelAsk if it was in flight (original did unconditional cancel when waiter matches).
      this.terminate(messageId, new Error(`No reply within ${timeoutMs}ms`), true);
    }, timeoutMs);

    const abortHandler = () => {
      const current = this.entries.get(messageId);
      if (!current) return;
      // Abort only cancels if the message was already sent (mirrors original onAbort sent check).
      const shouldCancel = current.sent;
      this.terminate(messageId, new Error("Ask cancelled"), shouldCancel);
    };

    const cleanup = () => {
      signal.removeEventListener("abort", abortHandler);
    };

    const fullEntry: AskEntry = {
      messageId,
      resolve,
      reject,
      timer,
      signal,
      abortHandler,
      cleanup,
      sent: false,
    };

    this.entries.set(messageId, fullEntry);
    signal.addEventListener("abort", abortHandler, { once: true });
    if (signal.aborted) {
      abortHandler();
    }

    return promise;
  }

  markSent(messageId: string): void {
    const entry = this.entries.get(messageId);
    if (entry) entry.sent = true;
  }

  /** Resolve a pending ask with an incoming reply. Returns true if matched. */
  resolveIncoming(replyTo: string, message: ActiveSessionMessage): boolean {
    const entry = this.entries.get(replyTo);
    if (!entry) return false;
    clearTimeout(entry.timer);
    entry.cleanup();
    this.entries.delete(replyTo);
    entry.resolve(message);
    return true;
  }

  /** Fail a pending ask without unconditional cancel (used for send errors / delivery failures). */
  fail(messageId: string, error: Error, shouldCancel = false): void {
    this.terminate(messageId, error, shouldCancel);
  }

  /** Fail all pending asks, cancelling those that were already sent. */
  failAll(error: Error): void {
    const ids = [...this.entries.keys()];
    for (const id of ids) {
      const entry = this.entries.get(id);
      const shouldCancel = entry?.sent ?? false;
      this.terminate(id, error, shouldCancel);
    }
  }

  private terminate(messageId: string, error: Error, shouldCancel: boolean): void {
    const entry = this.entries.get(messageId);
    if (!entry) return;
    clearTimeout(entry.timer);
    entry.cleanup();
    this.entries.delete(messageId);
    entry.reject(error);
    if (shouldCancel) {
      try {
        const transport = this.transportProvider();
        if (transport) transport.cancelAsk(messageId);
      } catch {
        // Broker cancel failures are non-fatal for waiter cleanup.
      }
    }
  }
}
