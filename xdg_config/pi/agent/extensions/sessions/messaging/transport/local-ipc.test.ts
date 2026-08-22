import { mkdtemp, readFile, rm, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, test } from "vitest";
import { LocalIpcTransport, localIpcSocketPath } from "./local-ipc.ts";
import type { ActiveSessionMessage } from "./index.ts";

const transports: LocalIpcTransport[] = [];
const directories: string[] = [];

afterEach(async () => {
  await Promise.all(transports.splice(0).map((transport) => transport.disconnect()));
  await Promise.all(directories.splice(0).map((directory) => rm(directory, { recursive: true, force: true })));
});

describe("LocalIpcTransport", () => {
  test("connects two transports, lists, sends, receives, and cleans up", async () => {
    const directory = await mkdtemp(join(tmpdir(), "pi-local-ipc-"));
    directories.push(directory);
    const first = new LocalIpcTransport(directory);
    const second = new LocalIpcTransport(directory);
    const third = new LocalIpcTransport(directory);
    transports.push(first, second, third);
    const registration = (name: string, pid: number) => ({
      name,
      cwd: directory,
      model: "test-model",
      pid,
      startedAt: Date.now(),
      lastActivity: Date.now(),
      status: "idle",
    });

    await first.connect(registration("first", 1), "first");
    await second.connect(registration("second", 2), "second");
    await third.connect(registration("third", 3), "third");

    const sessions = await first.listSessions();
    expect(sessions.map((session) => session.id).sort()).toEqual(["first", "second", "third"]);

    const received = new Promise<{ from: string; message: ActiveSessionMessage }>((resolve) => {
      second.onMessage((from, message) => resolve({ from: from.id, message }));
    });
    const sent = await first.send("second", { text: "hello", messageId: "message-1" });
    expect(sent).toEqual({ id: "message-1", delivered: true });
    await expect(received).resolves.toMatchObject({
      from: "first",
      message: { id: "message-1", content: { text: "hello" } },
    });
    await expect(first.cancel("message-1")).resolves.toMatchObject({
      delivered: false,
      reason: "Message is not pending",
    });

    await first.disconnect();
    await expect(second.listSessions()).resolves.toHaveLength(2);
    await expect(second.send("third", { text: "after owner exit" })).resolves.toMatchObject({ delivered: true });
    await second.disconnect();
    await expect(third.listSessions()).resolves.toHaveLength(1);
    await third.disconnect();
    await expect(stat(localIpcSocketPath(directory))).rejects.toMatchObject({ code: "ENOENT" });
  });

  test("cancels pending asks, rejects late replies, and closes asks on reply", async () => {
    const directory = await mkdtemp(join(tmpdir(), "pi-local-ipc-"));
    directories.push(directory);
    const first = new LocalIpcTransport(directory);
    const second = new LocalIpcTransport(directory);
    transports.push(first, second);
    const registration = (name: string, pid: number) => ({
      name,
      cwd: directory,
      model: "test-model",
      pid,
      startedAt: Date.now(),
      lastActivity: Date.now(),
      status: "idle",
    });
    await first.connect(registration("first", 1), "first");
    await second.connect(registration("second", 2), "second");

    const cancelled = new Promise<string>((resolve) => second.onCancelled(resolve));
    const firstAsk = new Promise<ActiveSessionMessage>((resolve) => {
      second.onMessage((_from, message) => resolve(message));
    });
    await expect(first.send("second", {
      text: "first ask",
      messageId: "ask-1",
      expectsReply: true,
    })).resolves.toMatchObject({ delivered: true });
    await expect(firstAsk).resolves.toMatchObject({ id: "ask-1", expectsReply: true });

    await expect(first.cancel("ask-1")).resolves.toMatchObject({ delivered: true });
    await expect(cancelled).resolves.toBe("ask-1");
    await expect(second.send("first", {
      text: "late reply",
      replyTo: "ask-1",
    })).resolves.toMatchObject({
      delivered: false,
      reason: "Question is no longer pending",
    });

    const secondAsk = new Promise<ActiveSessionMessage>((resolve) => {
      second.onMessage((_from, message) => {
        if (message.id === "ask-2") resolve(message);
      });
    });
    await expect(first.send("second", {
      text: "second ask",
      messageId: "ask-2",
      expectsReply: true,
    })).resolves.toMatchObject({ delivered: true });
    await expect(secondAsk).resolves.toMatchObject({ id: "ask-2" });
    await expect(second.send("first", {
      text: "on-time reply",
      replyTo: "ask-2",
    })).resolves.toMatchObject({ delivered: true });
    await expect(first.cancel("ask-2")).resolves.toMatchObject({
      delivered: false,
      reason: "Message is not pending",
    });
  });

  test("uses private runtime and socket permissions", async () => {
    const directory = await mkdtemp(join(tmpdir(), "pi-local-ipc-"));
    directories.push(directory);
    const transport = new LocalIpcTransport(directory);
    transports.push(transport);
    await transport.connect({
      cwd: directory,
      model: "test-model",
      pid: process.pid,
      startedAt: Date.now(),
      lastActivity: Date.now(),
    }, "permissions");
    expect((await stat(join(directory, "runtime"))).mode & 0o777).toBe(0o700);
    expect((await stat(localIpcSocketPath(directory))).mode & 0o777).toBe(0o600);
    await expect(readFile(localIpcSocketPath(directory), "utf8")).rejects.toBeDefined();
  });
});
