// Adds a TUI for archiving, restoring, and navigating inactive conversation branches.

import {
  type CustomEntry,
  type ExtensionAPI,
  type ExtensionCommandContext,
  type ExtensionContext,
  type KeybindingsManager,
  type SessionEntry,
  type SessionTreeNode,
  type Theme,
} from "@earendil-works/pi-coding-agent";
import { type Component, matchesKey, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import {
  buildArchiveTransaction,
  buildRestoreTransaction,
  commitSessionTransaction,
  getActivePhysicalArchive,
  materializeArchivedEntries,
  readSessionSnapshot,
  removeTransactionBackup,
  rollbackSessionTransaction,
  type ActivePhysicalArchive,
  SessionTransactionCommitError,
  type SessionSnapshot,
} from "./storage";

const ARCHIVE_ENTRY_TYPE = "branch-archive";

type ArchiveEvent =
  | {
    op: "archive";
    version?: number;
    rootId: string;
    resumeId: string;
    archivedAt: number;
  }
  | {
    op: "restore";
    version?: number;
    rootId: string;
    restoredAt: number;
  };

interface ArchivedBranch {
  rootId: string;
  resumeId: string;
  archivedAt: number;
}

interface LogicalNode {
  entry: SessionEntry;
  label?: string;
  parentId: string | null;
  children: string[];
  order: number;
}

interface LogicalTree {
  nodes: Map<string, LogicalNode>;
  roots: string[];
  leafId: string | null;
  physicalToLogical: Map<string, string | null>;
}

interface ArchiveAction {
  type: "toggle" | "navigate";
  nodeId: string;
}

interface TreeRow {
  node: LogicalNode;
  depth: number;
  isLast: boolean;
  ancestorLast: boolean[];
  showConnector: boolean;
}

interface BranchProjection {
  roots: string[];
  children: Map<string, string[]>;
}

function isArchiveMetadata(entry: SessionEntry): entry is CustomEntry {
  return entry.type === "custom" && entry.customType === ARCHIVE_ENTRY_TYPE;
}

export function shouldBlockArchiveNavigation(
  target: SessionEntry | undefined,
  activeArchiveEntryId: string | undefined,
): boolean {
  return !!target && isArchiveMetadata(target) && target.id === activeArchiveEntryId;
}

function buildSessionTree(entries: SessionEntry[]): SessionTreeNode[] {
  const byId = new Map<string, SessionTreeNode>();
  const labels = new Map<string, { label: string; timestamp: string }>();

  for (const entry of entries) {
    if (entry.type !== "label") continue;
    if (entry.label) labels.set(entry.targetId, { label: entry.label, timestamp: entry.timestamp });
    else labels.delete(entry.targetId);
  }
  for (const entry of entries) {
    const label = labels.get(entry.id);
    byId.set(entry.id, {
      entry,
      children: [],
      label: label?.label,
      labelTimestamp: label?.timestamp,
    });
  }

  const roots: SessionTreeNode[] = [];
  for (const entry of entries) {
    const node = byId.get(entry.id)!;
    const parent = entry.parentId ? byId.get(entry.parentId) : undefined;
    if (parent) parent.children.push(node);
    else roots.push(node);
  }
  const stack = [...roots];
  while (stack.length > 0) {
    const node = stack.pop()!;
    node.children.sort(
      (left, right) =>
        new Date(left.entry.timestamp).getTime() - new Date(right.entry.timestamp).getTime(),
    );
    stack.push(...node.children);
  }
  return roots;
}

export function buildLogicalTree(
  roots: SessionTreeNode[],
  physicalLeafId: string | null,
): LogicalTree {
  const nodes = new Map<string, LogicalNode>();
  const logicalRoots: string[] = [];
  const physicalToLogical = new Map<string, string | null>();
  let order = 0;

  const visit = (physical: SessionTreeNode, logicalParentId: string | null): void => {
    const { entry } = physical;
    if (isArchiveMetadata(entry)) {
      physicalToLogical.set(entry.id, logicalParentId);
      for (const child of physical.children) visit(child, logicalParentId);
      return;
    }

    const node: LogicalNode = {
      entry,
      label: physical.label,
      parentId: logicalParentId,
      children: [],
      order: order++,
    };
    nodes.set(entry.id, node);
    physicalToLogical.set(entry.id, entry.id);

    if (logicalParentId) {
      nodes.get(logicalParentId)?.children.push(entry.id);
    } else {
      logicalRoots.push(entry.id);
    }

    for (const child of physical.children) visit(child, entry.id);
  };

  for (const root of roots) visit(root, null);

  return {
    nodes,
    roots: logicalRoots,
    leafId: physicalLeafId ? (physicalToLogical.get(physicalLeafId) ?? null) : null,
    physicalToLogical,
  };
}

function isDescendant(tree: LogicalTree, rootId: string, nodeId: string): boolean {
  let current: LogicalNode | undefined = tree.nodes.get(nodeId);
  while (current) {
    if (current.entry.id === rootId) return true;
    current = current.parentId ? tree.nodes.get(current.parentId) : undefined;
  }
  return false;
}

function isBranchRoot(tree: LogicalTree, nodeId: string): boolean {
  const node = tree.nodes.get(nodeId);
  if (!node?.parentId) return false;
  return (tree.nodes.get(node.parentId)?.children.length ?? 0) > 1;
}

export function buildBranchProjection(tree: LogicalTree): BranchProjection {
  const roots: string[] = [];
  const children = new Map<string, string[]>();

  for (const node of tree.nodes.values()) {
    if (!isBranchRoot(tree, node.entry.id)) continue;

    let parent = node.parentId ? tree.nodes.get(node.parentId) : undefined;
    while (parent && !isBranchRoot(tree, parent.entry.id)) {
      parent = parent.parentId ? tree.nodes.get(parent.parentId) : undefined;
    }

    if (!parent) {
      roots.push(node.entry.id);
      continue;
    }
    const siblings = children.get(parent.entry.id) ?? [];
    siblings.push(node.entry.id);
    children.set(parent.entry.id, siblings);
  }

  return { roots, children };
}

function findCurrentBranchRoot(tree: LogicalTree): string | undefined {
  let current = tree.leafId ? tree.nodes.get(tree.leafId) : undefined;
  while (current) {
    if (isBranchRoot(tree, current.entry.id)) return current.entry.id;
    current = current.parentId ? tree.nodes.get(current.parentId) : undefined;
  }
  return undefined;
}

export function canArchiveBranch(tree: LogicalTree, nodeId: string): boolean {
  return isBranchRoot(tree, nodeId) && !(tree.leafId && isDescendant(tree, nodeId, tree.leafId));
}

function isArchiveEvent(value: unknown): value is ArchiveEvent {
  if (!value || typeof value !== "object") return false;
  const event = value as Record<string, unknown>;
  if (event.op === "archive") {
    return (
      typeof event.rootId === "string" &&
      typeof event.resumeId === "string" &&
      typeof event.archivedAt === "number" &&
      Number.isFinite(event.archivedAt)
    );
  }
  return (
    event.op === "restore" &&
    typeof event.rootId === "string" &&
    typeof event.restoredAt === "number" &&
    Number.isFinite(event.restoredAt)
  );
}

export function rebuildArchiveState(
  entries: SessionEntry[],
  tree: LogicalTree,
): Map<string, ArchivedBranch> {
  const replayed = new Map<string, ArchivedBranch>();

  for (const entry of entries) {
    if (!isArchiveMetadata(entry) || !isArchiveEvent(entry.data)) continue;
    const event = entry.data;
    // Metadata-only events from earlier extension versions did not modify the
    // native tree. Treat them as historical so users can physically archive
    // those branches with the current implementation.
    if (event.version !== 1) continue;
    if (event.op === "restore") {
      replayed.delete(event.rootId);
    } else {
      replayed.set(event.rootId, {
        rootId: event.rootId,
        resumeId: event.resumeId,
        archivedAt: event.archivedAt,
      });
    }
  }

  const valid = [...replayed.values()]
    .filter(
      (branch) =>
        isBranchRoot(tree, branch.rootId) &&
        tree.nodes.has(branch.resumeId) &&
        isDescendant(tree, branch.rootId, branch.resumeId),
    )
    .sort((left, right) => {
      const leftNode = tree.nodes.get(left.rootId);
      const rightNode = tree.nodes.get(right.rootId);
      return (leftNode?.order ?? 0) - (rightNode?.order ?? 0);
    });

  const normalized = new Map<string, ArchivedBranch>();
  for (const branch of valid) {
    const insideArchivedAncestor = [...normalized.keys()].some((rootId) =>
      isDescendant(tree, rootId, branch.rootId),
    );
    if (!insideArchivedAncestor) normalized.set(branch.rootId, branch);
  }
  return normalized;
}

function readState(ctx: ExtensionContext): {
  tree: LogicalTree;
  archived: Map<string, ArchivedBranch>;
  physicalArchive?: ActivePhysicalArchive;
} {
  const liveEntries = ctx.sessionManager.getEntries();
  const physicalArchive = getActivePhysicalArchive(liveEntries);
  const entries = physicalArchive
    ? materializeArchivedEntries(liveEntries, physicalArchive)
    : liveEntries;
  const tree = buildLogicalTree(
    physicalArchive ? buildSessionTree(entries) : ctx.sessionManager.getTree(),
    ctx.sessionManager.getLeafId(),
  );
  return {
    tree,
    archived: rebuildArchiveState(entries, tree),
    physicalArchive,
  };
}

interface DiskArchiveState {
  snapshot: SessionSnapshot;
  tree: LogicalTree;
  archived: Map<string, ArchivedBranch>;
  physicalArchive?: ActivePhysicalArchive;
}

function readDiskState(sessionPath: string, activeLeafId: string | null): DiskArchiveState {
  const snapshot = readSessionSnapshot(sessionPath);
  const liveEntries = snapshot.records.map((record) => record.entry);
  const physicalArchive = getActivePhysicalArchive(liveEntries);
  const entries = physicalArchive
    ? materializeArchivedEntries(liveEntries, physicalArchive)
    : liveEntries;
  const tree = buildLogicalTree(buildSessionTree(entries), activeLeafId);
  return {
    snapshot,
    tree,
    archived: rebuildArchiveState(entries, tree),
    physicalArchive,
  };
}

function verifyReloadedSession(
  expected: SessionSnapshot,
  actual: SessionSnapshot,
  managerEntries: SessionEntry[],
): boolean {
  if (
    actual.headerRaw !== expected.headerRaw ||
    actual.records.length < expected.records.length ||
    expected.records.some((record, index) => actual.records[index]?.raw !== record.raw)
  ) {
    return false;
  }
  return (
    managerEntries.length === actual.records.length &&
    managerEntries.every((entry, index) => entry.id === actual.records[index]?.entry.id)
  );
}

function findContainingArchivedBranch(
  nodeId: string,
  tree: LogicalTree,
  archived: Map<string, ArchivedBranch>,
): ArchivedBranch | undefined {
  return [...archived.values()].find((branch) => isDescendant(tree, branch.rootId, nodeId));
}

function preferredResumeId(tree: LogicalTree, rootId: string): string {
  if (tree.leafId && isDescendant(tree, rootId, tree.leafId)) return tree.leafId;

  let preferred = tree.nodes.get(rootId);
  for (const node of tree.nodes.values()) {
    if (node.children.length > 0 || !isDescendant(tree, rootId, node.entry.id)) continue;
    const nodeTime = Date.parse(node.entry.timestamp) || 0;
    const preferredTime = preferred ? Date.parse(preferred.entry.timestamp) || 0 : -1;
    if (
      !preferred ||
      nodeTime > preferredTime ||
      (nodeTime === preferredTime && node.order > preferred.order)
    ) {
      preferred = node;
    }
  }
  return preferred?.entry.id ?? rootId;
}

function descendantCount(tree: LogicalTree, rootId: string): number {
  let count = 0;
  const stack = [...(tree.nodes.get(rootId)?.children ?? [])];
  while (stack.length > 0) {
    const id = stack.pop()!;
    count++;
    stack.push(...(tree.nodes.get(id)?.children ?? []));
  }
  return count;
}

function extractText(content: unknown): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content
    .filter(
      (item): item is { type: "text"; text: string } =>
        !!item &&
        typeof item === "object" &&
        "type" in item &&
        item.type === "text" &&
        "text" in item &&
        typeof item.text === "string",
    )
    .map((item) => item.text)
    .join("");
}

function nodeText(node: LogicalNode): string {
  if (node.label) return `[${node.label}]`;
  const entry = node.entry;
  switch (entry.type) {
    case "message": {
      const message = entry.message;
      if (message.role === "user" || message.role === "assistant") {
        const text = extractText(message.content)
          .replace(/[\n\t]+/g, " ")
          .trim();
        return `${message.role}: ${text || "(no content)"}`;
      }
      if (message.role === "toolResult") return `[${message.toolName ?? "tool"}]`;
      if (message.role === "bashExecution") return `[bash] ${message.command ?? ""}`;
      return `[${message.role}]`;
    }
    case "custom_message":
      return `[${entry.customType}] ${extractText(entry.content)
        .replace(/[\n\t]+/g, " ")
        .trim()}`;
    case "compaction":
      return `[compaction: ${Math.round(entry.tokensBefore / 1000)}k tokens]`;
    case "branch_summary":
      return `[branch summary] ${entry.summary.replace(/[\n\t]+/g, " ").trim()}`;
    case "model_change":
      return `[model: ${entry.modelId}]`;
    case "thinking_level_change":
      return `[thinking: ${entry.thinkingLevel}]`;
    case "label":
      return `[label: ${entry.label ?? "cleared"}]`;
    case "session_info":
      return `[title: ${entry.name ?? "empty"}]`;
    case "custom":
      return `[custom: ${entry.customType}]`;
  }
}

class ArchiveTreeComponent implements Component {
  private selectedId: string | undefined;
  private message = "";
  private busy = false;
  private disposed = false;

  constructor(
    private tree: LogicalTree,
    private archived: Map<string, ArchivedBranch>,
    private readonly collapsed: Set<string>,
    selectedId: string | undefined,
    private readonly maxVisibleRows: number,
    private readonly theme: Theme,
    private readonly keybindings: KeybindingsManager,
    private readonly requestRender: () => void,
    private readonly done: (action: ArchiveAction | undefined) => void,
    private readonly toggle: (
      nodeId: string,
    ) => Promise<{ tree: LogicalTree; archived: Map<string, ArchivedBranch>; restored: boolean }>,
  ) {
    this.selectedId = selectedId ?? findCurrentBranchRoot(tree);
    this.ensureVisibleSelection();
  }

  invalidate(): void { }

  dispose(): void {
    this.disposed = true;
  }

  private rows(): TreeRow[] {
    const rows: TreeRow[] = [];
    const projection = buildBranchProjection(this.tree);
    const visit = (
      id: string,
      depth: number,
      isLast: boolean,
      ancestorLast: boolean[],
      showConnector: boolean,
    ): void => {
      const node = this.tree.nodes.get(id);
      if (!node) return;
      rows.push({ node, depth, isLast, ancestorLast, showConnector });
      if (this.archived.has(id) && this.collapsed.has(id)) return;
      const children = projection.children.get(id) ?? [];
      children.forEach((childId, index) =>
        visit(childId, depth + 1, index === children.length - 1, [...ancestorLast, isLast], true),
      );
    };
    projection.roots.forEach((rootId, index) =>
      visit(rootId, 0, index === projection.roots.length - 1, [], false),
    );
    return rows;
  }

  private ensureVisibleSelection(): void {
    const visible = this.rows();
    if (visible.some((row) => row.node.entry.id === this.selectedId)) return;
    const containing = this.selectedId
      ? findContainingArchivedBranch(this.selectedId, this.tree, this.archived)
      : undefined;
    this.selectedId = containing?.rootId ?? visible[0]?.node.entry.id;
  }

  private selectedRow(): TreeRow | undefined {
    return this.rows().find((row) => row.node.entry.id === this.selectedId);
  }

  private canToggle(nodeId: string): boolean {
    return (
      this.archived.has(nodeId) ||
      (canArchiveBranch(this.tree, nodeId) &&
        !findContainingArchivedBranch(nodeId, this.tree, this.archived))
    );
  }

  handleInput(data: string): void {
    if (this.busy || this.disposed) return;
    const rows = this.rows();
    const index = Math.max(
      0,
      rows.findIndex((row) => row.node.entry.id === this.selectedId),
    );

    if (this.keybindings.matches(data, "tui.select.up")) {
      this.selectedId = rows[(index - 1 + rows.length) % rows.length]?.node.entry.id;
    } else if (this.keybindings.matches(data, "tui.select.down")) {
      this.selectedId = rows[(index + 1) % rows.length]?.node.entry.id;
    } else if (matchesKey(data, "left")) {
      const selected = this.selectedRow();
      if (selected && this.archived.has(selected.node.entry.id)) {
        this.collapsed.add(selected.node.entry.id);
      } else if (selected) {
        const containing = findContainingArchivedBranch(
          selected.node.entry.id,
          this.tree,
          this.archived,
        );
        if (containing) {
          this.collapsed.add(containing.rootId);
          this.selectedId = containing.rootId;
        }
      }
    } else if (matchesKey(data, "right")) {
      const selected = this.selectedRow();
      if (selected && this.archived.has(selected.node.entry.id)) {
        this.collapsed.delete(selected.node.entry.id);
      }
    } else if (data === " ") {
      const selected = this.selectedRow();
      if (selected && this.canToggle(selected.node.entry.id)) {
        const nodeId = selected.node.entry.id;
        this.busy = true;
        this.message = "Working…";
        this.requestRender();
        void this.toggle(nodeId).then(
          (result) => {
            if (this.disposed) return;
            this.tree = result.tree;
            this.archived = result.archived;
            if (result.restored) this.collapsed.delete(nodeId);
            else this.collapsed.add(nodeId);
            this.selectedId = nodeId;
            this.ensureVisibleSelection();
            this.message = result.restored ? "Branch restored" : "Branch archived";
          },
          (error) => {
            if (!this.disposed)
              this.message = error instanceof Error ? error.message : String(error);
          },
        ).finally(() => {
          if (this.disposed) return;
          this.busy = false;
          this.requestRender();
        });
        return;
      }
      this.message =
        selected && this.tree.leafId &&
          isDescendant(this.tree, selected.node.entry.id, this.tree.leafId)
          ? "The current branch cannot be archived"
          : "Space is only available on branch roots";
    } else if (this.keybindings.matches(data, "tui.select.confirm")) {
      const selected = this.selectedRow();
      if (selected) {
        this.disposed = true;
        this.done({ type: "navigate", nodeId: selected.node.entry.id });
        return;
      }
    } else if (this.keybindings.matches(data, "tui.select.cancel")) {
      this.disposed = true;
      this.done(undefined);
      return;
    }

    this.requestRender();
  }

  render(width: number): string[] {
    const rows = this.rows();
    const currentId = findCurrentBranchRoot(this.tree);
    const selectedIndex = Math.max(
      0,
      rows.findIndex((row) => row.node.entry.id === this.selectedId),
    );
    const start = Math.max(
      0,
      Math.min(
        selectedIndex - Math.floor(this.maxVisibleRows / 2),
        rows.length - this.maxVisibleRows,
      ),
    );
    const end = Math.min(rows.length, start + this.maxVisibleRows);
    const lines = [this.theme.fg("accent", this.theme.bold("  Archive Branches")), ""];

    for (let index = start; index < end; index++) {
      const row = rows[index];
      const id = row.node.entry.id;
      const selected = id === this.selectedId;
      const prefix =
        row.depth === 0
          ? ""
          : `${row.ancestorLast
            .slice(1)
            .map((last) => (last ? "   " : "│  "))
            .join("")}${row.showConnector ? (row.isLast ? "└─ " : "├─ ") : "   "}`;
      const exactArchive = this.archived.has(id);
      const containingArchive = findContainingArchivedBranch(id, this.tree, this.archived);
      const hidden = exactArchive && this.collapsed.has(id) ? descendantCount(this.tree, id) : 0;
      const statuses = [
        exactArchive ? "archived" : undefined,
        hidden > 0 ? `${hidden} hidden` : undefined,
        id === currentId ? "current" : undefined,
      ].filter(Boolean);
      const marker = selected ? this.theme.fg("accent", "› ") : "  ";
      const text = nodeText(row.node);
      const styledText = containingArchive
        ? this.theme.fg("dim", text)
        : selected
          ? this.theme.bold(text)
          : text;
      const status =
        statuses.length > 0
          ? this.theme.fg(exactArchive ? "warning" : "muted", `  ${statuses.join(", ")}`)
          : "";
      let line = `${marker}${this.theme.fg("dim", prefix)}${styledText}${status}`;
      if (selected) line = this.theme.bg("selectedBg", line);
      lines.push(truncateToWidth(line, width, ""));
    }

    if (rows.length === 0) {
      lines.push(this.theme.fg("muted", "  No conversation branches"));
    }
    if (rows.length > this.maxVisibleRows) {
      lines.push(this.theme.fg("muted", `  (${selectedIndex + 1}/${rows.length})`));
    }
    lines.push("");
    lines.push(
      truncateToWidth(
        this.theme.fg(
          "muted",
          "  ↑↓ navigate  ←→ collapse/expand  Space archive/restore  Enter jump  Esc close",
        ),
        width,
        "",
      ),
    );
    if (this.message)
      lines.push(truncateToWidth(this.theme.fg("warning", `  ${this.message}`), width, ""));
    return lines.map((line) =>
      visibleWidth(line) > width ? truncateToWidth(line, width, "") : line,
    );
  }
}

async function showArchiveTree(
  tree: LogicalTree,
  archived: Map<string, ArchivedBranch>,
  collapsed: Set<string>,
  selectedId: string | undefined,
  ctx: ExtensionCommandContext,
  toggle: (
    nodeId: string,
  ) => Promise<{ tree: LogicalTree; archived: Map<string, ArchivedBranch>; restored: boolean }>,
): Promise<ArchiveAction | undefined> {
  return ctx.ui.custom<ArchiveAction | undefined>(
    (tui, theme, keybindings, done) =>
      new ArchiveTreeComponent(
        tree,
        archived,
        collapsed,
        selectedId,
        Math.max(5, Math.floor(tui.terminal.rows / 2)),
        theme,
        keybindings,
        () => tui.requestRender(),
        done,
        toggle,
      ),
  );
}

export default function archiveExtension(pi: ExtensionAPI): void {
  let archived = new Map<string, ArchivedBranch>();

  pi.on("session_start", async (_event, ctx) => {
    archived = readState(ctx).archived;
  });

  pi.on("session_before_tree", (event, ctx) => {
    const target = ctx.sessionManager.getEntry(event.preparation.targetId);
    const active = getActivePhysicalArchive(ctx.sessionManager.getEntries());
    if (!shouldBlockArchiveNavigation(target, active?.entry.id)) return;

    ctx.ui.notify("Use /archive to restore this branch", "warning");
    return { cancel: true };
  });

  pi.registerCommand("archive", {
    description: "Manage archived conversation branches",
    handler: async (_args, ctx) => {
      if (ctx.mode !== "tui") {
        ctx.ui.notify("/archive requires interactive mode", "error");
        return;
      }

      if (!ctx.isIdle() || ctx.hasPendingMessages()) {
        ctx.ui.notify("Wait for the current response and queued messages to finish", "warning");
        return;
      }
      const sessionPath = ctx.sessionManager.getSessionFile();
      if (!sessionPath) {
        ctx.ui.notify("Archive requires a persisted session", "error");
        return;
      }

      const managerState = readState(ctx);
      const activeLeafId = managerState.tree.leafId;
      const initial = readDiskState(sessionPath, activeLeafId);
      let expectedDigest = initial.snapshot.digest;
      let baselineBackup: string | undefined;
      let mutated = false;

      const mutate = async (rootId: string) => {
        const state = readDiskState(sessionPath, activeLeafId);
        if (state.snapshot.digest !== expectedDigest) {
          throw new Error("Session changed while the archive picker was open");
        }
        const existing = state.archived.get(rootId);
        const transaction = existing
          ? buildRestoreTransaction(
            state.snapshot,
            state.physicalArchive ?? (() => { throw new Error("Archived branch payload is unavailable"); })(),
          )
          : (() => {
            if (state.physicalArchive)
              throw new Error("Restore the archived branch before archiving another branch");
            if (!canArchiveBranch(state.tree, rootId))
              throw new Error(
                state.tree.leafId && isDescendant(state.tree, rootId, state.tree.leafId)
                  ? "The current branch cannot be archived"
                  : "Only branch roots can be archived",
              );
            return buildArchiveTransaction(
              state.snapshot,
              rootId,
              preferredResumeId(state.tree, rootId),
              activeLeafId,
            );
          })();
        let committed: ReturnType<typeof commitSessionTransaction>;
        try {
          committed = commitSessionTransaction(state.snapshot, transaction.bytes);
        } catch (error) {
          if (error instanceof SessionTransactionCommitError) {
            try {
              rollbackSessionTransaction(state.snapshot, error.backupPath, error.targetDigest);
            } catch (rollbackError) {
              ctx.ui.notify(
                `Archive transaction could not be rolled back; recovery backup: ${error.backupPath}`,
                "error",
              );
              ctx.shutdown();
              throw rollbackError;
            }
            throw new Error("Archive transaction failed durability verification and was rolled back", {
              cause: error,
            });
          }
          throw error;
        }
        try {
          const verified = readDiskState(sessionPath, activeLeafId);
          const active = verified.physicalArchive;
          if (
            verified.snapshot.digest !== committed.targetDigest ||
            (existing ? !!active : active?.entry.id !== transaction.event.id)
          ) {
            throw new Error("Disk verification failed after archive transaction");
          }
          if (!baselineBackup) baselineBackup = committed.backupPath;
          else removeTransactionBackup(committed.backupPath);
          expectedDigest = committed.targetDigest;
          mutated = true;
          archived = verified.archived;
          return { tree: verified.tree, archived: verified.archived, restored: !!existing };
        } catch (error) {
          rollbackSessionTransaction(state.snapshot, committed.backupPath, committed.targetDigest);
          throw error;
        }
      };

      archived = initial.archived;
      const action = await showArchiveTree(
        initial.tree,
        archived,
        new Set(archived.keys()),
        undefined,
        ctx,
        mutate,
      );
      let navigateId: string | undefined;
      if (action?.type === "navigate") {
        const state = readDiskState(sessionPath, activeLeafId);
        const branch = state.archived.get(action.nodeId) ??
          findContainingArchivedBranch(action.nodeId, state.tree, state.archived);
        if (branch) {
          navigateId = action.nodeId === branch.rootId ? branch.resumeId : action.nodeId;
          try {
            await mutate(branch.rootId);
          } catch (error) {
            navigateId = undefined;
            ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
          }
        } else navigateId = action.nodeId;
      }
      if (!mutated) {
        if (navigateId) await ctx.navigateTree(navigateId, { summarize: false });
        return;
      }

      const finalState = readDiskState(sessionPath, activeLeafId);
      if (finalState.snapshot.digest !== expectedDigest) {
        ctx.ui.notify(
          `Session changed before reload; recovery backup: ${baselineBackup}`,
          "error",
        );
        return;
      }
      let replacementVerified = false;
      try {
        const switched = await ctx.switchSession(sessionPath, {
          withSession: async (newCtx) => {
            const disk = readDiskState(sessionPath, activeLeafId);
            const managerEntries = newCtx.sessionManager.getEntries();
            const managerActive = getActivePhysicalArchive(managerEntries);
            if (
              !verifyReloadedSession(finalState.snapshot, disk.snapshot, managerEntries) ||
              managerActive?.entry.id !== finalState.physicalArchive?.entry.id ||
              disk.physicalArchive?.entry.id !== finalState.physicalArchive?.entry.id
            ) throw new Error("Session reload did not verify the final archive state");
            replacementVerified = true;
            if (baselineBackup) {
              try {
                removeTransactionBackup(baselineBackup);
              } catch {
                newCtx.ui.notify(`Archive changes applied; remove backup manually: ${baselineBackup}`, "warning");
              }
            }
            if (navigateId) {
              try {
                await newCtx.navigateTree(navigateId, { summarize: false });
              } catch (error) {
                newCtx.ui.notify(
                  `Archive changes applied, but navigation failed: ${error instanceof Error ? error.message : String(error)}`,
                  "error",
                );
              }
            }
          },
        });
        if (switched.cancelled) {
          rollbackSessionTransaction(initial.snapshot, baselineBackup!, expectedDigest);
          ctx.ui.notify("Session switch was cancelled; archive changes rolled back", "warning");
        } else if (!replacementVerified) {
          throw new Error(`Session replacement was not verified; backup: ${baselineBackup}`);
        }
      } catch (error) {
        ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
        throw error;
      }
    },
  });
}
