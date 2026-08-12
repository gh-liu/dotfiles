import { randomUUID } from "node:crypto";
import { chmod, mkdir, rm } from "node:fs/promises";
import { dirname } from "node:path";
import net from "node:net";

const socketPath = process.argv[2];
const clients = new Map();
const pending = new Map();
const maxFrame = 256 * 1024;
const maxMessage = 64 * 1024;

const packet = (value) => {
  const data = Buffer.from(`${JSON.stringify(value)}\n`);
  if (data.byteLength > maxFrame) throw new Error(`IPC frame exceeds ${maxFrame} bytes`);
  return data;
};
const send = (socket, value) => socket.write(packet(value));
const respond = (socket, id, result, error) => send(socket, error
  ? { type: "response", requestId: id, ok: false, error }
  : { type: "response", requestId: id, ok: true, result });
const validRegistration = (v) => v && typeof v.cwd === "string" && typeof v.model === "string"
  && typeof v.pid === "number" && typeof v.startedAt === "number" && typeof v.lastActivity === "number"
  && (v.name === undefined || typeof v.name === "string") && (v.status === undefined || typeof v.status === "string");
const validMessage = (v) => v && typeof v.id === "string" && typeof v.timestamp === "number"
  && v.content && typeof v.content.text === "string" && Buffer.byteLength(v.content.text) <= maxMessage;

function remove(client) {
  clients.delete(client.socket);
  for (const [id, value] of pending) if (value.sender === client.socket || value.target === client.socket) pending.delete(id);
  if (!clients.size) server.close(() => rm(socketPath, { force: true }));
}
function handle(client, request) {
  try {
    if (request.op === "register") {
      if (client.session || !validRegistration(request.registration)) throw new Error("Invalid session registration");
      const id = request.sessionId?.trim() || randomUUID();
      if ([...clients.values()].some((v) => v.session?.id === id)) throw new Error(`Session id is already connected: ${id}`);
      client.session = { id, ...request.registration }; respond(client.socket, request.id, client.session); return;
    }
    if (!client.session) throw new Error("Client is not registered");
    if (request.op === "list") {
      respond(client.socket, request.id, [...clients.values()].flatMap((v) => v.session ? [v.session] : [])); return;
    }
    if (request.op === "send") {
      if (!request.to || !validMessage(request.message)) throw new Error("Invalid message request");
      const target = [...clients.values()].find((v) => v.session?.id === request.to);
      if (!target?.session) { respond(client.socket, request.id, { id: request.message.id, delivered: false, reason: "Target session is not connected" }); return; }
      send(target.socket, { type: "message", from: client.session, message: request.message });
      pending.set(request.message.id, { sender: client.socket, target: target.socket });
      respond(client.socket, request.id, { id: request.message.id, delivered: true }); return;
    }
    if (request.op === "cancel") {
      const value = pending.get(request.messageId);
      if (!value || value.sender !== client.socket) { respond(client.socket, request.id, { id: request.messageId, delivered: false, reason: "Message is not pending" }); return; }
      send(value.target, { type: "cancel", messageId: request.messageId }); pending.delete(request.messageId);
      respond(client.socket, request.id, { id: request.messageId, delivered: true }); return;
    }
    throw new Error("Unknown IPC operation");
  } catch (error) { respond(client.socket, request.id, undefined, error.message); }
}
function read(client, chunk) {
  client.buffer = Buffer.concat([client.buffer, chunk]);
  if (client.buffer.byteLength > maxFrame && !client.buffer.includes(10)) return client.socket.destroy();
  for (;;) {
    const newline = client.buffer.indexOf(10); if (newline < 0) return;
    const line = client.buffer.subarray(0, newline); client.buffer = client.buffer.subarray(newline + 1);
    if (line.byteLength > maxFrame) return client.socket.destroy();
    try { const request = JSON.parse(line); if (request.type !== "request" || typeof request.id !== "string") respond(client.socket, request.id ?? "", undefined, "Invalid IPC request"); else handle(client, request); }
    catch { respond(client.socket, "", undefined, "Invalid IPC packet"); }
  }
}
const server = net.createServer((socket) => {
  const client = { socket, buffer: Buffer.alloc(0) }; clients.set(socket, client);
  socket.on("data", (chunk) => read(client, chunk)); socket.on("error", () => socket.destroy()); socket.on("close", () => remove(client));
});
await mkdir(dirname(socketPath), { recursive: true, mode: 0o700 }); await chmod(dirname(socketPath), 0o700);
await new Promise((resolve, reject) => { server.once("error", reject); server.listen(socketPath, resolve); });
await chmod(socketPath, 0o600);
