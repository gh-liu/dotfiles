import {
  closeSync,
  copyFileSync,
  existsSync,
  fsyncSync,
  openSync,
  readFileSync,
  renameSync,
  statSync,
  unlinkSync,
  writeFileSync,
  constants,
} from "node:fs";
import { createHash, randomUUID } from "node:crypto";
import { dirname, join } from "node:path";
import type { CustomEntry, SessionEntry, SessionHeader } from "@earendil-works/pi-coding-agent";

export interface ArchivedRecord {
  id: string;
  ordinal: number;
  raw: string;
  digest: string;
}

export interface PhysicalArchiveEvent {
  op: "archive";
  version: 1;
  txId: string;
  sessionId: string;
  rootId: string;
  resumeId: string;
  archivedAt: number;
  snapshotDigest: string;
  retainedDigest: string;
  originalEntryCount: number;
  records: ArchivedRecord[];
}

export interface PhysicalRestoreEvent {
  op: "restore";
  version: 1;
  txId: string;
  archiveTxId: string;
  rootId: string;
  restoredAt: number;
}

interface RawRecord {
  raw: string;
  entry: SessionEntry;
  ordinal: number;
}

export interface SessionSnapshot {
  path: string;
  headerRaw: string;
  header: SessionHeader;
  records: RawRecord[];
  bytes: Buffer;
  digest: string;
  inode: number;
  size: number;
  mtimeMs: number;
  mode: number;
}

export interface SessionTransaction {
  bytes: Buffer;
  event: CustomEntry<PhysicalArchiveEvent | PhysicalRestoreEvent>;
}

export interface ActivePhysicalArchive {
  entry: CustomEntry<PhysicalArchiveEvent>;
  event: PhysicalArchiveEvent;
}

export class SessionTransactionCommitError extends Error {
  constructor(
    message: string,
    readonly backupPath: string,
    readonly targetDigest: string,
    options: { cause: unknown },
  ) {
    super(message, options);
    this.name = "SessionTransactionCommitError";
  }
}

function digest(value: string | Buffer): string {
  return createHash("sha256").update(value).digest("hex");
}

function isObject(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === "object";
}

export function isPhysicalArchiveEvent(value: unknown): value is PhysicalArchiveEvent {
  if (!isObject(value) || value.op !== "archive" || value.version !== 1) return false;
  const originalEntryCount = value.originalEntryCount;
  if (
    !(
      typeof value.txId === "string" &&
      typeof value.sessionId === "string" &&
      typeof value.rootId === "string" &&
      typeof value.resumeId === "string" &&
      typeof value.archivedAt === "number" &&
      typeof value.snapshotDigest === "string" &&
      typeof value.retainedDigest === "string" &&
      typeof originalEntryCount === "number" &&
      Number.isInteger(originalEntryCount) &&
      originalEntryCount >= 0 &&
      Array.isArray(value.records) &&
      value.records.length > 0
    )
  )
    return false;

  const ids = new Set<string>();
  const ordinals = new Set<number>();
  for (const record of value.records) {
    if (!isObject(record)) return false;
    const ordinal = record.ordinal;
    if (
      typeof record.id !== "string" ||
      ids.has(record.id) ||
      typeof ordinal !== "number" ||
      !Number.isInteger(ordinal) ||
      ordinal < 0 ||
      ordinal >= originalEntryCount ||
      ordinals.has(ordinal) ||
      typeof record.raw !== "string" ||
      typeof record.digest !== "string" ||
      digest(record.raw) !== record.digest
    )
      return false;
    let parsed: unknown;
    try {
      parsed = JSON.parse(record.raw);
    } catch {
      return false;
    }
    if (!isObject(parsed) || parsed.id !== record.id || typeof parsed.type !== "string")
      return false;
    ids.add(record.id);
    ordinals.add(ordinal);
  }
  return ids.has(value.rootId as string) && ids.has(value.resumeId as string);
}

function isPhysicalRestoreEvent(value: unknown): value is PhysicalRestoreEvent {
  return (
    isObject(value) &&
    value.op === "restore" &&
    value.version === 1 &&
    typeof value.txId === "string" &&
    typeof value.archiveTxId === "string" &&
    typeof value.rootId === "string" &&
    typeof value.restoredAt === "number"
  );
}

function parseSnapshot(path: string, bytes: Buffer): SessionSnapshot {
  if (bytes.length === 0 || bytes[bytes.length - 1] !== 0x0a) {
    throw new Error("Session JSONL must end with a newline");
  }
  const lines = bytes.toString("utf8").split("\n");
  lines.pop();
  if (lines.length === 0 || lines.some((line) => line.length === 0)) {
    throw new Error("Session JSONL contains an empty line");
  }

  let header: SessionHeader;
  try {
    header = JSON.parse(lines[0]) as SessionHeader;
  } catch {
    throw new Error("Session header is not valid JSON");
  }
  if (header.type !== "session" || header.version !== 3 || typeof header.id !== "string") {
    throw new Error("Session JSONL has an invalid header");
  }

  const records: RawRecord[] = [];
  const ids = new Set<string>();
  for (let index = 1; index < lines.length; index++) {
    let entry: SessionEntry;
    try {
      entry = JSON.parse(lines[index]) as SessionEntry;
    } catch {
      throw new Error(`Session entry line ${index + 1} is not valid JSON`);
    }
    if (!entry || typeof entry.id !== "string" || typeof entry.type !== "string") {
      throw new Error(`Session entry line ${index + 1} is invalid`);
    }
    if (ids.has(entry.id)) throw new Error(`Duplicate session entry id: ${entry.id}`);
    ids.add(entry.id);
    records.push({ raw: lines[index], entry, ordinal: index - 1 });
  }

  const byId = new Map(records.map((record) => [record.entry.id, record.entry]));
  for (const { entry } of records) {
    if (entry.parentId !== null && !byId.has(entry.parentId)) {
      throw new Error(`Session entry ${entry.id} has missing parent ${entry.parentId}`);
    }
  }

  const complete = new Set<string>();
  for (const { entry } of records) {
    if (complete.has(entry.id)) continue;
    const visited = new Set<string>();
    let current: SessionEntry | undefined = entry;
    while (current && !complete.has(current.id)) {
      if (visited.has(current.id)) throw new Error(`Session entry cycle at ${current.id}`);
      visited.add(current.id);
      current = current.parentId ? byId.get(current.parentId) : undefined;
    }
    for (const id of visited) complete.add(id);
  }

  const stat = statSync(path);
  return {
    path,
    headerRaw: lines[0],
    header,
    records,
    bytes,
    digest: digest(bytes),
    inode: stat.ino,
    size: stat.size,
    mtimeMs: stat.mtimeMs,
    mode: stat.mode,
  };
}

export function readSessionSnapshot(path: string): SessionSnapshot {
  return parseSnapshot(path, readFileSync(path));
}

function uniqueId(ids: Set<string>): string {
  let id = randomUUID();
  while (ids.has(id)) id = randomUUID();
  return id;
}

function serialize(headerRaw: string, records: string[]): Buffer {
  return Buffer.from(`${[headerRaw, ...records].join("\n")}\n`, "utf8");
}

export function collectPhysicalSubtreeIds(snapshot: SessionSnapshot, rootId: string): Set<string> {
  if (!snapshot.records.some((record) => record.entry.id === rootId)) {
    throw new Error(`Archive root ${rootId} is not present in the session file`);
  }
  const children = new Map<string, string[]>();
  for (const { entry } of snapshot.records) {
    if (!entry.parentId) continue;
    const siblings = children.get(entry.parentId) ?? [];
    siblings.push(entry.id);
    children.set(entry.parentId, siblings);
  }
  const result = new Set<string>();
  const stack = [rootId];
  while (stack.length > 0) {
    const id = stack.pop()!;
    if (result.has(id)) continue;
    result.add(id);
    stack.push(...(children.get(id) ?? []));
  }
  return result;
}

function validateArchiveBoundary(snapshot: SessionSnapshot, extractedIds: Set<string>): void {
  for (const { entry } of snapshot.records) {
    const extracted = extractedIds.has(entry.id);
    if (!extracted && entry.parentId && extractedIds.has(entry.parentId)) {
      throw new Error(`Retained entry ${entry.id} depends on archived parent ${entry.parentId}`);
    }
    if (!extracted && entry.type === "compaction" && extractedIds.has(entry.firstKeptEntryId)) {
      throw new Error(`Compaction ${entry.id} references the archived subtree`);
    }
    if (!extracted && entry.type === "branch_summary" && extractedIds.has(entry.fromId)) {
      throw new Error(`Branch summary ${entry.id} references the archived subtree`);
    }
    if (!extracted && entry.type === "label" && extractedIds.has(entry.targetId)) {
      throw new Error(`Retained label ${entry.id} targets the archived subtree`);
    }
    if (extracted && entry.type === "label" && !extractedIds.has(entry.targetId)) {
      throw new Error(`Archived label ${entry.id} targets a retained entry`);
    }
  }
}

export function buildArchiveTransaction(
  snapshot: SessionSnapshot,
  rootId: string,
  resumeId: string,
  activeLeafId: string | null,
): SessionTransaction {
  if (getActivePhysicalArchive(snapshot.records.map((record) => record.entry))) {
    throw new Error("Restore the active physical archive before creating another one");
  }
  const extractedIds = collectPhysicalSubtreeIds(snapshot, rootId);
  const root = snapshot.records.find((record) => record.entry.id === rootId)?.entry;
  if (!root?.parentId) throw new Error("The session root cannot be archived");
  if (activeLeafId && !snapshot.records.some((record) => record.entry.id === activeLeafId)) {
    throw new Error(`Active leaf ${activeLeafId} is not present in the session file`);
  }
  const eventParentId =
    activeLeafId && !extractedIds.has(activeLeafId) ? activeLeafId : root.parentId;
  if (!extractedIds.has(resumeId)) {
    throw new Error(`Resume entry ${resumeId} is outside the archived subtree`);
  }
  if (extractedIds.has(eventParentId))
    throw new Error("Archive event parent is inside the subtree");
  validateArchiveBoundary(snapshot, extractedIds);

  const retained = snapshot.records.filter((record) => !extractedIds.has(record.entry.id));
  const extracted = snapshot.records.filter((record) => extractedIds.has(record.entry.id));
  const ids = new Set(snapshot.records.map((record) => record.entry.id));
  const txId = randomUUID();
  const event: CustomEntry<PhysicalArchiveEvent> = {
    type: "custom",
    customType: "branch-archive",
    id: uniqueId(ids),
    parentId: eventParentId,
    timestamp: new Date().toISOString(),
    data: {
      op: "archive",
      version: 1,
      txId,
      sessionId: snapshot.header.id,
      rootId,
      resumeId,
      archivedAt: Date.now(),
      snapshotDigest: snapshot.digest,
      retainedDigest: digest(retained.map((record) => record.raw).join("\n")),
      originalEntryCount: snapshot.records.length,
      records: extracted.map((record) => ({
        id: record.entry.id,
        ordinal: record.ordinal,
        raw: record.raw,
        digest: digest(record.raw),
      })),
    },
  };
  const bytes = serialize(snapshot.headerRaw, [
    ...retained.map((record) => record.raw),
    JSON.stringify(event),
  ]);
  parseSnapshot(snapshot.path, bytes);
  return { bytes, event };
}

export function getActivePhysicalArchive(
  entries: SessionEntry[],
): ActivePhysicalArchive | undefined {
  let active: ActivePhysicalArchive | undefined;
  for (const entry of entries) {
    if (entry.type !== "custom" || entry.customType !== "branch-archive") continue;
    if (isPhysicalArchiveEvent(entry.data)) {
      if (active) throw new Error("Multiple physical archives are not supported");
      active = { entry: entry as CustomEntry<PhysicalArchiveEvent>, event: entry.data };
    } else if (isObject(entry.data) && entry.data.op === "archive" && entry.data.version === 1) {
      throw new Error(`Physical archive event ${entry.id} is invalid or corrupted`);
    } else if (isPhysicalRestoreEvent(entry.data)) {
      if (!active) throw new Error(`Physical restore event ${entry.id} has no active archive`);
      if (entry.data.archiveTxId !== active.event.txId || entry.data.rootId !== active.event.rootId)
        throw new Error(`Physical restore event ${entry.id} does not match its archive`);
      active = undefined;
    } else if (
      isObject(entry.data) &&
      entry.data.op === "restore" &&
      entry.data.version === 1 &&
      !isPhysicalRestoreEvent(entry.data)
    ) {
      throw new Error(`Physical restore event ${entry.id} is invalid or corrupted`);
    }
  }
  return active;
}

function restoreOriginalRecords(
  retained: RawRecord[],
  event: PhysicalArchiveEvent,
  verifyRetainedDigest = true,
): string[] {
  if (
    verifyRetainedDigest &&
    digest(retained.map((record) => record.raw).join("\n")) !== event.retainedDigest
  ) {
    throw new Error("Retained session prefix changed since archive");
  }
  const slots = new Array<string | undefined>(event.originalEntryCount);
  for (const record of event.records) {
    if (record.ordinal >= slots.length || slots[record.ordinal] !== undefined) {
      throw new Error("Archive payload has an invalid record ordinal");
    }
    slots[record.ordinal] = record.raw;
  }
  let retainedIndex = 0;
  for (let index = 0; index < slots.length; index++) {
    if (slots[index] === undefined) slots[index] = retained[retainedIndex++]?.raw;
  }
  if (retainedIndex !== retained.length || slots.some((line) => line === undefined)) {
    throw new Error("Archive payload cannot reconstruct the original session ordering");
  }
  return slots as string[];
}

export function buildRestoreTransaction(
  snapshot: SessionSnapshot,
  active: ActivePhysicalArchive,
): SessionTransaction {
  const snapshotActive = getActivePhysicalArchive(snapshot.records.map((record) => record.entry));
  if (
    !snapshotActive ||
    snapshotActive.entry.id !== active.entry.id ||
    snapshotActive.event.txId !== active.event.txId
  )
    throw new Error("Active archive changed while the restore transaction was being prepared");
  active = snapshotActive;
  if (active.event.sessionId !== snapshot.header.id) {
    throw new Error("Archive payload belongs to a different session");
  }
  const archiveIndex = snapshot.records.findIndex((record) => record.entry.id === active.entry.id);
  if (archiveIndex < 0) throw new Error("Archive event is missing from the session");

  const liveIds = new Set(snapshot.records.map((record) => record.entry.id));
  if (active.event.records.some((record) => liveIds.has(record.id))) {
    throw new Error("Archived entries are already present in the live session");
  }
  const retained = snapshot.records.slice(0, archiveIndex);
  const suffix = snapshot.records.slice(archiveIndex);
  const original = restoreOriginalRecords(retained, active.event);
  if (digest(serialize(snapshot.headerRaw, original)) !== active.event.snapshotDigest) {
    throw new Error("Archive payload cannot reproduce the original session snapshot");
  }
  const ids = new Set([...liveIds, ...active.event.records.map((record) => record.id)]);
  const restore: CustomEntry<PhysicalRestoreEvent> = {
    type: "custom",
    customType: "branch-archive",
    id: uniqueId(ids),
    parentId: snapshot.records.at(-1)?.entry.id ?? null,
    timestamp: new Date().toISOString(),
    data: {
      op: "restore",
      version: 1,
      txId: randomUUID(),
      archiveTxId: active.event.txId,
      rootId: active.event.rootId,
      restoredAt: Date.now(),
    },
  };
  const bytes = serialize(snapshot.headerRaw, [
    ...original,
    ...suffix.map((record) => record.raw),
    JSON.stringify(restore),
  ]);
  parseSnapshot(snapshot.path, bytes);
  return { bytes, event: restore };
}

export function materializeArchivedEntries(
  entries: SessionEntry[],
  active: ActivePhysicalArchive,
): SessionEntry[] {
  const archiveIndex = entries.findIndex((entry) => entry.id === active.entry.id);
  if (archiveIndex < 0) throw new Error("Archive event is missing from live entries");
  const retained = entries.slice(0, archiveIndex).map((entry, ordinal) => ({
    raw: JSON.stringify(entry),
    entry,
    ordinal,
  }));
  // SessionManager exposes parsed entries rather than their original JSONL
  // bytes. Ordinals still reconstruct the display tree exactly; byte-level
  // digest verification remains mandatory for the disk restore transaction.
  const originalRaw = restoreOriginalRecords(retained, active.event, false);
  const original = originalRaw.map((raw) => JSON.parse(raw) as SessionEntry);
  return [...original, ...entries.slice(archiveIndex)];
}

export function commitSessionTransaction(
  snapshot: SessionSnapshot,
  bytes: Buffer,
): { backupPath: string; targetDigest: string } {
  const txId = randomUUID();
  const directory = dirname(snapshot.path);
  const tempPath = join(directory, `.pi-archive-${txId}.tmp`);
  const backupPath = join(directory, `.pi-archive-${txId}.bak`);
  let tempCreated = false;
  let backupCreated = false;
  let targetReplaced = false;
  try {
    const fd = openSync(
      tempPath,
      constants.O_CREAT | constants.O_EXCL | constants.O_WRONLY,
      snapshot.mode & 0o777,
    );
    tempCreated = true;
    try {
      writeFileSync(fd, bytes);
      fsyncSync(fd);
    } finally {
      closeSync(fd);
    }
    parseSnapshot(snapshot.path, bytes);

    copyFileSync(snapshot.path, backupPath, constants.COPYFILE_EXCL);
    backupCreated = true;
    const current = readSessionSnapshot(snapshot.path);
    if (
      current.digest !== snapshot.digest ||
      current.inode !== snapshot.inode ||
      current.size !== snapshot.size ||
      current.mtimeMs !== snapshot.mtimeMs
    ) {
      throw new Error("Session changed while the archive transaction was being prepared");
    }

    renameSync(tempPath, snapshot.path);
    tempCreated = false;
    targetReplaced = true;
    const directoryFd = openSync(directory, constants.O_RDONLY);
    try {
      fsyncSync(directoryFd);
    } finally {
      closeSync(directoryFd);
    }
    return { backupPath, targetDigest: digest(bytes) };
  } catch (error) {
    if (tempCreated && existsSync(tempPath)) unlinkSync(tempPath);
    if (backupCreated && !targetReplaced && existsSync(backupPath)) unlinkSync(backupPath);
    if (targetReplaced) {
      throw new SessionTransactionCommitError(
        `Session file was replaced but durability verification failed; backup: ${backupPath}`,
        backupPath,
        digest(bytes),
        { cause: error },
      );
    }
    throw error;
  }
}

export function rollbackSessionTransaction(
  snapshot: SessionSnapshot,
  backupPath: string,
  targetDigest: string,
): void {
  if (readSessionSnapshot(snapshot.path).digest !== targetDigest) {
    throw new Error(
      `Session reload was cancelled and the changed file cannot be rolled back safely; backup: ${backupPath}`,
    );
  }
  if (digest(readFileSync(backupPath)) !== snapshot.digest) {
    throw new Error(`Session transaction backup is invalid: ${backupPath}`);
  }
  renameSync(backupPath, snapshot.path);
  const directoryFd = openSync(dirname(snapshot.path), constants.O_RDONLY);
  try {
    fsyncSync(directoryFd);
  } finally {
    closeSync(directoryFd);
  }
}

export function removeTransactionBackup(path: string): void {
  unlinkSync(path);
}
