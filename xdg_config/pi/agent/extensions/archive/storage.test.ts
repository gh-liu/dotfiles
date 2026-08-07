import { afterEach, describe, expect, test } from "vitest";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import {
  SessionManager,
  type SessionEntry,
  type SessionTreeNode,
} from "@earendil-works/pi-coding-agent";
import {
  buildArchiveTransaction,
  buildRestoreTransaction,
  commitSessionTransaction,
  getActivePhysicalArchive,
  materializeArchivedEntries,
  readSessionSnapshot,
  removeTransactionBackup,
  rollbackSessionTransaction,
} from "./storage.ts";

const temporaryDirectories: string[] = [];

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

function temporarySession(name = "session.jsonl"): string {
  const directory = mkdtempSync(join(tmpdir(), "pi-archive-test-"));
  temporaryDirectories.push(directory);
  return join(directory, name);
}

function info(id: string, parentId: string | null): SessionEntry {
  return {
    type: "session_info",
    id,
    parentId,
    timestamp: `2026-08-07T00:00:0${id.charCodeAt(0) % 10}.000Z`,
    name: id,
  };
}

function writeSyntheticSession(
  path: string,
  entries: SessionEntry[] = [info("A", null), info("B", "A"), info("C", "A"), info("D", "B")],
): void {
  const lines = [
    JSON.stringify({
      type: "session",
      version: 3,
      id: "test-session",
      timestamp: "2026-08-07T00:00:00.000Z",
      cwd: "/tmp",
    }),
    ...entries.map((entry) => JSON.stringify(entry)),
  ];
  writeFileSync(path, `${lines.join("\n")}\n`);
}

function treeIds(roots: SessionTreeNode[]): Set<string> {
  const ids = new Set<string>();
  const stack = [...roots];
  while (stack.length > 0) {
    const node = stack.pop()!;
    ids.add(node.entry.id);
    stack.push(...node.children);
  }
  return ids;
}

function commitArchive(path: string, rootId: string, resumeId: string, activeLeafId: string) {
  const snapshot = readSessionSnapshot(path);
  const transaction = buildArchiveTransaction(snapshot, rootId, resumeId, activeLeafId);
  const committed = commitSessionTransaction(snapshot, transaction.bytes);
  return { snapshot, transaction, committed };
}

describe("physical archive transactions", () => {
  test("removes a subtree from native tree and restores exact original records", () => {
    const path = temporarySession();
    writeSyntheticSession(path);
    const original = readSessionSnapshot(path);

    const archived = commitArchive(path, "B", "D", "C");
    expect(existsSync(archived.committed.backupPath)).toBe(true);
    const archivedManager = SessionManager.open(path);
    const archivedIds = treeIds(archivedManager.getTree());
    expect(archivedIds.has("B")).toBe(false);
    expect(archivedIds.has("D")).toBe(false);
    expect(archivedIds.has("A")).toBe(true);
    expect(archivedIds.has("C")).toBe(true);

    const archivedSnapshot = readSessionSnapshot(path);
    const active = getActivePhysicalArchive(archivedSnapshot.records.map((record) => record.entry));
    expect(active?.event.rootId).toBe("B");
    expect(active?.entry.parentId).toBe("C");
    expect(active?.event.records.map((record) => record.id)).toEqual(["B", "D"]);
    expect(
      materializeArchivedEntries(
        archivedSnapshot.records.map((record) => record.entry),
        active!,
      )
        .slice(0, original.records.length)
        .map((entry) => entry.id),
    ).toEqual(original.records.map((record) => record.entry.id));

    const restore = buildRestoreTransaction(archivedSnapshot, active!);
    const restored = commitSessionTransaction(archivedSnapshot, restore.bytes);
    const restoredSnapshot = readSessionSnapshot(path);
    expect(
      restoredSnapshot.records.slice(0, original.records.length).map((record) => record.raw),
    ).toEqual(original.records.map((record) => record.raw));
    expect(
      getActivePhysicalArchive(restoredSnapshot.records.map((record) => record.entry)),
    ).toBeUndefined();
    const restoredIds = treeIds(SessionManager.open(path).getTree());
    expect(restoredIds.has("B")).toBe(true);
    expect(restoredIds.has("D")).toBe(true);

    removeTransactionBackup(archived.committed.backupPath);
    removeTransactionBackup(restored.backupPath);
  });

  test("rejects a stale snapshot without overwriting a concurrent append", () => {
    const path = temporarySession();
    writeSyntheticSession(path);
    const snapshot = readSessionSnapshot(path);
    const transaction = buildArchiveTransaction(snapshot, "B", "D", "A");
    const appended = `${readFileSync(path, "utf8")}${JSON.stringify(info("E", "C"))}\n`;
    writeFileSync(path, appended);

    expect(() => commitSessionTransaction(snapshot, transaction.bytes)).toThrow(
      "Session changed while the archive transaction was being prepared",
    );
    expect(readFileSync(path, "utf8")).toBe(appended);
  });

  test("rolls back a committed transaction when session reload is cancelled", () => {
    const path = temporarySession();
    writeSyntheticSession(path);
    const original = readFileSync(path);
    const archived = commitArchive(path, "B", "D", "C");

    rollbackSessionTransaction(
      archived.snapshot,
      archived.committed.backupPath,
      archived.committed.targetDigest,
    );

    expect(readFileSync(path)).toEqual(original);
    expect(existsSync(archived.committed.backupPath)).toBe(false);
  });

  test("moves the leaf to the branch parent when archiving the current branch", () => {
    const path = temporarySession();
    writeSyntheticSession(path);
    const snapshot = readSessionSnapshot(path);
    const transaction = buildArchiveTransaction(snapshot, "B", "D", "D");

    expect(transaction.event.parentId).toBe("A");
  });

  test("fails closed when the archive payload is modified", () => {
    const path = temporarySession();
    writeSyntheticSession(path);
    const archived = commitArchive(path, "B", "D", "A");
    const lines = readFileSync(path, "utf8").trimEnd().split("\n");
    const event = JSON.parse(lines.at(-1)!);
    event.data.records[0].raw = `${event.data.records[0].raw} `;
    lines[lines.length - 1] = JSON.stringify(event);
    writeFileSync(path, `${lines.join("\n")}\n`);

    const snapshot = readSessionSnapshot(path);
    expect(() => getActivePhysicalArchive(snapshot.records.map((record) => record.entry))).toThrow(
      "invalid or corrupted",
    );
    removeTransactionBackup(archived.committed.backupPath);
  });

  test("rejects a second active physical archive", () => {
    const path = temporarySession();
    writeSyntheticSession(path);
    const archived = commitArchive(path, "B", "D", "A");
    const snapshot = readSessionSnapshot(path);

    expect(() => buildArchiveTransaction(snapshot, "C", "C", "A")).toThrow(
      "Restore the active physical archive",
    );
    removeTransactionBackup(archived.committed.backupPath);
  });

  test("rejects payload ordinals that do not reproduce the original snapshot", () => {
    const path = temporarySession();
    writeSyntheticSession(path);
    const archived = commitArchive(path, "B", "D", "C");
    const lines = readFileSync(path, "utf8").trimEnd().split("\n");
    const entry = JSON.parse(lines.at(-1)!);
    const records = entry.data.records;
    [records[0].ordinal, records[1].ordinal] = [records[1].ordinal, records[0].ordinal];
    lines[lines.length - 1] = JSON.stringify(entry);
    writeFileSync(path, `${lines.join("\n")}\n`);
    const snapshot = readSessionSnapshot(path);
    const active = getActivePhysicalArchive(snapshot.records.map((record) => record.entry));

    expect(() => buildRestoreTransaction(snapshot, active!)).toThrow(
      "cannot reproduce the original session snapshot",
    );
    removeTransactionBackup(archived.committed.backupPath);
  });
});

describe("mock session copies", () => {
  const sessions = [
    {
      name: "root-branch.jsonl",
      entries: [info("A", null), info("B", "A"), info("C", "A"), info("D", "B")],
    },
    {
      name: "nested-branch.jsonl",
      entries: [
        info("A", null),
        info("B", "A"),
        info("C", "B"),
        info("D", "B"),
        info("E", "C"),
        info("F", "D"),
      ],
    },
  ];

  for (const session of sessions) {
    test(`round-trips original records from ${session.name}`, () => {
      const path = temporarySession(session.name);
      writeSyntheticSession(path, session.entries);
      const original = readSessionSnapshot(path);
      const manager = SessionManager.open(path);
      const branchParent = [...manager.getTree()]
        .flatMap(function flatten(node): SessionTreeNode[] {
          return [node, ...node.children.flatMap(flatten)];
        })
        .find((node) => node.children.length > 1);
      expect(branchParent).toBeDefined();
      const root = branchParent!.children[0];
      let resume = root;
      while (resume.children.length > 0) resume = resume.children.at(-1)!;

      const archived = commitArchive(path, root.entry.id, resume.entry.id, manager.getLeafId()!);
      const archivedEntries = readSessionSnapshot(path);
      const active = getActivePhysicalArchive(
        archivedEntries.records.map((record) => record.entry),
      );
      expect(active).toBeDefined();
      const nativeIds = treeIds(SessionManager.open(path).getTree());
      expect(nativeIds.has(root.entry.id)).toBe(false);

      const restore = buildRestoreTransaction(archivedEntries, active!);
      const restored = commitSessionTransaction(archivedEntries, restore.bytes);
      const restoredSnapshot = readSessionSnapshot(path);
      expect(
        restoredSnapshot.records.slice(0, original.records.length).map((record) => record.raw),
      ).toEqual(original.records.map((record) => record.raw));
      expect(treeIds(SessionManager.open(path).getTree()).has(root.entry.id)).toBe(true);

      removeTransactionBackup(archived.committed.backupPath);
      removeTransactionBackup(restored.backupPath);
    });
  }
});
