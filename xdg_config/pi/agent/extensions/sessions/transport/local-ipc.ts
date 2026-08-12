import { randomUUID } from "node:crypto";
import { spawn } from "node:child_process";
import { rm } from "node:fs/promises";
import { homedir, platform } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import net from "node:net";
import type { Socket } from "node:net";
import type {
  ActiveSession,
  ActiveSessionCancellationHandler,
  ActiveSessionDisconnectedHandler,
  ActiveSessionMessage,
  ActiveSessionMessageHandler,
  ActiveSessionRegistration,
  ActiveSessionSendOptions,
  ActiveSessionSendResult,
  ActiveSessionTransport,
} from "./index.ts";

export const MAX_IPC_MESSAGE_BYTES = 64 * 1024;
export const MAX_IPC_FRAME_BYTES = 256 * 1024;

const runtimeDirectoryName = "runtime";
const socketFileName = "sessions.sock";
const unsupportedPlatformError = "Local IPC transport requires Unix domain sockets and is not supported on Windows";

type WireRequest = {
  type: "request";
  id: string;
  op: "register" | "list" | "send" | "cancel";
  sessionId?: string;
  registration?: ActiveSessionRegistration;
  to?: string;
  message?: ActiveSessionMessage;
  messageId?: string;
};

type WireResponse = {
  type: "response";
  requestId: string;
  ok: boolean;
  result?: unknown;
  error?: string;
};

type WireMessage = {
  type: "message";
  from: ActiveSession;
  message: ActiveSessionMessage;
};

type WireCancel = {
  type: "cancel";
  messageId: string;
};

type WirePacket = WireResponse | WireMessage | WireCancel;
type PendingRequest = { resolve: (value: unknown) => void; reject: (error: Error) => void };

function agentDirectory(): string {
  return resolve(process.env.PI_CODING_AGENT_DIR?.trim() || join(homedir(), ".pi", "agent"));
}

export function localIpcSocketPath(agentDir = agentDirectory()): string {
  return join(resolve(agentDir), runtimeDirectoryName, socketFileName);
}

function startStandaloneBroker(socketPath: string): void {
  const child = spawn(process.execPath, [
    ...process.execArgv,
    fileURLToPath(new URL("./local-ipc-broker.mjs", import.meta.url)),
    socketPath,
  ], { detached: true, stdio: "ignore" });
  child.unref();
}

function errorCode(error: unknown): string | undefined {
  return error && typeof error === "object" && "code" in error ? String(error.code) : undefined;
}

function packetBytes(packet: object): Buffer {
  const encoded = Buffer.from(`${JSON.stringify(packet)}\n`, "utf8");
  if (encoded.byteLength > MAX_IPC_FRAME_BYTES) throw new Error(`IPC frame exceeds ${MAX_IPC_FRAME_BYTES} bytes`);
  return encoded;
}

function writePacket(socket: Socket, packet: object): void {
  socket.write(packetBytes(packet));
}

export class LocalIpcTransport implements ActiveSessionTransport {
  private socket: Socket | null = null;
  private currentSessionId: string | null = null;
  private readonly pending = new Map<string, PendingRequest>();
  private readonly messageHandlers = new Set<ActiveSessionMessageHandler>();
  private readonly cancellationHandlers = new Set<ActiveSessionCancellationHandler>();
  private readonly disconnectedHandlers = new Set<ActiveSessionDisconnectedHandler>();
  private buffer = Buffer.alloc(0);
  private intentionalDisconnect = false;
  private disconnected = false;

  constructor(private readonly agentDir = agentDirectory()) {}

  get sessionId(): string | null {
    return this.currentSessionId;
  }

  async connect(registration: ActiveSessionRegistration, sessionId?: string): Promise<void> {
    if (platform() === "win32") throw new Error(unsupportedPlatformError);
    if (this.socket) throw new Error("Local IPC transport is already connected");
    const socketPath = localIpcSocketPath(this.agentDir);
    let socket: Socket;
    try {
      socket = await this.open(socketPath);
    } catch (error) {
      const code = errorCode(error);
      if (code !== "ENOENT" && code !== "ECONNREFUSED") throw error;
      if (code === "ECONNREFUSED") await rm(socketPath, { force: true }).catch(() => undefined);
      startStandaloneBroker(socketPath);
      socket = await this.openWhenReady(socketPath);
    }
    this.socket = socket;
    this.disconnected = false;
    this.intentionalDisconnect = false;
    try {
      const result = await this.request("register", { registration, sessionId }) as ActiveSession;
      this.currentSessionId = result.id;
    } catch (error) {
      this.intentionalDisconnect = true;
      socket.destroy();
      throw error;
    }
  }

  async listSessions(): Promise<ActiveSession[]> {
    this.requireSocket();
    return await this.request("list") as ActiveSession[];
  }

  async send(to: string, options: ActiveSessionSendOptions): Promise<ActiveSessionSendResult> {
    this.requireSocket();
    if (Buffer.byteLength(options.text, "utf8") > MAX_IPC_MESSAGE_BYTES) {
      return { id: options.messageId ?? randomUUID(), delivered: false, reason: `Message exceeds ${MAX_IPC_MESSAGE_BYTES} bytes` };
    }
    const message: ActiveSessionMessage = {
      id: options.messageId ?? randomUUID(),
      timestamp: Date.now(),
      replyTo: options.replyTo,
      expectsReply: options.expectsReply,
      content: { text: options.text },
    };
    return await this.request("send", { to, message }) as ActiveSessionSendResult;
  }

  cancel(messageId: string): Promise<ActiveSessionSendResult> {
    this.requireSocket();
    return this.request("cancel", { messageId }) as Promise<ActiveSessionSendResult>;
  }

  cancelAsk(messageId: string): void {
    void this.cancel(messageId).catch(() => undefined);
  }

  async disconnect(): Promise<void> {
    const socket = this.socket;
    if (!socket) return;
    this.intentionalDisconnect = true;
    this.socket = null;
    this.currentSessionId = null;
    for (const request of this.pending.values()) request.reject(new Error("Local IPC transport disconnected"));
    this.pending.clear();
    await new Promise<void>((resolveClose) => {
      socket.once("close", () => resolveClose());
      socket.end();
      if (socket.destroyed) resolveClose();
    });
    // The standalone broker remains alive for other connected transports and closes itself when empty.
  }

  onMessage(handler: ActiveSessionMessageHandler): () => void {
    this.messageHandlers.add(handler);
    return () => this.messageHandlers.delete(handler);
  }

  onCancelled(handler: ActiveSessionCancellationHandler): () => void {
    this.cancellationHandlers.add(handler);
    return () => this.cancellationHandlers.delete(handler);
  }

  onDisconnected(handler: ActiveSessionDisconnectedHandler): () => void {
    this.disconnectedHandlers.add(handler);
    return () => this.disconnectedHandlers.delete(handler);
  }

  private requireSocket(): Socket {
    if (!this.socket || this.disconnected) throw new Error("Local IPC transport is not connected");
    return this.socket;
  }

  private async openWhenReady(socketPath: string): Promise<Socket> {
    let lastError: unknown;
    for (let attempt = 0; attempt < 100; attempt += 1) {
      try {
        return await this.open(socketPath);
      } catch (error) {
        lastError = error;
        if (errorCode(error) !== "ENOENT" && errorCode(error) !== "ECONNREFUSED") throw error;
        await new Promise((resolveWait) => setTimeout(resolveWait, 10));
      }
    }
    throw lastError instanceof Error ? lastError : new Error("Local IPC broker did not start");
  }

  private open(socketPath: string): Promise<Socket> {
    return new Promise<Socket>((resolveOpen, rejectOpen) => {
      const socket = net.createConnection(socketPath);
      const onError = (error: Error) => {
        socket.off("connect", onConnect);
        rejectOpen(error);
      };
      const onConnect = () => {
        socket.off("error", onError);
        socket.setNoDelay(true);
        this.attach(socket);
        resolveOpen(socket);
      };
      socket.once("error", onError);
      socket.once("connect", onConnect);
    });
  }

  private attach(socket: Socket): void {
    socket.on("data", (chunk: Buffer) => this.read(chunk));
    socket.on("error", (error) => this.handleDisconnect(error));
    socket.on("close", () => this.handleDisconnect(new Error("Local IPC socket closed")));
  }

  private read(chunk: Buffer): void {
    this.buffer = Buffer.concat([this.buffer, chunk]);
    if (this.buffer.byteLength > MAX_IPC_FRAME_BYTES && !this.buffer.includes(10)) {
      this.socket?.destroy(new Error(`IPC frame exceeds ${MAX_IPC_FRAME_BYTES} bytes`));
      return;
    }
    for (;;) {
      const newline = this.buffer.indexOf(10);
      if (newline < 0) return;
      const line = this.buffer.subarray(0, newline);
      this.buffer = this.buffer.subarray(newline + 1);
      if (line.byteLength > MAX_IPC_FRAME_BYTES) {
        this.socket?.destroy(new Error(`IPC frame exceeds ${MAX_IPC_FRAME_BYTES} bytes`));
        return;
      }
      let packet: WirePacket;
      try {
        packet = JSON.parse(line.toString("utf8")) as WirePacket;
      } catch {
        this.socket?.destroy(new Error("Invalid IPC packet"));
        return;
      }
      if (packet.type === "response") {
        const request = this.pending.get(packet.requestId);
        if (!request) continue;
        this.pending.delete(packet.requestId);
        if (packet.ok) request.resolve(packet.result);
        else request.reject(new Error(packet.error ?? "Local IPC request failed"));
      } else if (packet.type === "message") {
        const message = packet as WireMessage;
        this.messageHandlers.forEach((handler) => handler(message.from, message.message));
      } else if (packet.type === "cancel") {
        this.cancellationHandlers.forEach((handler) => handler(packet.messageId));
      }
    }
  }

  private request(op: WireRequest["op"], values: Omit<WireRequest, "type" | "id" | "op"> = {}): Promise<unknown> {
    const socket = this.requireSocket();
    const id = randomUUID();
    const request: WireRequest = { type: "request", id, op, ...values };
    return new Promise((resolveRequest, rejectRequest) => {
      this.pending.set(id, { resolve: resolveRequest, reject: rejectRequest });
      try {
        writePacket(socket, request);
      } catch (error) {
        this.pending.delete(id);
        rejectRequest(error instanceof Error ? error : new Error(String(error)));
      }
    });
  }

  private handleDisconnect(error: Error): void {
    if (this.disconnected || this.intentionalDisconnect) return;
    this.disconnected = true;
    this.socket = null;
    this.currentSessionId = null;
    for (const request of this.pending.values()) request.reject(error);
    this.pending.clear();
    this.disconnectedHandlers.forEach((handler) => handler(error));
  }
}

export function createLocalIpcTransport(): ActiveSessionTransport {
  return new LocalIpcTransport();
}
