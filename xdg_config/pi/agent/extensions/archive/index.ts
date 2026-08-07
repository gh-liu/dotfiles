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
import {
  type Component,
  matchesKey,
  truncateToWidth,
  visibleWidth,
} from "@earendil-works/pi-tui";
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

function findContainingArchivedBranch(
  nodeId: string,
  tree: LogicalTree,
  archived: Map<string, ArchivedBranch>,
): ArchivedBranch | undefined {
  return [...archived.values()].find((branch) =>
    isDescendant(tree, branch.rootId, nodeId),
  );
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

async function toggleArchive(
  rootId: string,
  ctx: ExtensionCommandContext,
): Promise<boolean> {
  if (!ctx.isIdle() || ctx.hasPendingMessages()) {
    ctx.ui.notify("Wait for the current response and queued messages to finish", "warning");
    return false;
  }

  const sessionPath = ctx.sessionManager.getSessionFile();
  if (!sessionPath) {
    ctx.ui.notify("Archive requires a persisted session", "error");
    return false;
  }

  const { tree, archived, physicalArchive } = readState(ctx);
  const existing = archived.get(rootId);
  try {
    const snapshot = readSessionSnapshot(sessionPath);
    const transaction = existing
      ? buildRestoreTransaction(snapshot, physicalArchive ?? (() => {
          throw new Error("Archived branch payload is unavailable");
        })())
      : (() => {
          if (physicalArchive) {
            throw new Error("Restore the archived branch before archiving another branch");
          }
          if (!isBranchRoot(tree, rootId)) {
            throw new Error("Only branch roots can be archived");
          }
          if (!tree.nodes.get(rootId)?.parentId) {
            throw new Error("The session root cannot be archived");
          }
          return buildArchiveTransaction(
            snapshot,
            rootId,
            preferredResumeId(tree, rootId),
            ctx.sessionManager.getLeafId(),
          );
        })();

    const committed = commitSessionTransaction(snapshot, transaction.bytes);
    let verified = false;
    let replacementStarted = false;
    try {
      const switched = await ctx.switchSession(sessionPath, {
        withSession: async (newCtx) => {
          replacementStarted = true;
          try {
            const active = getActivePhysicalArchive(newCtx.sessionManager.getEntries());
            verified =
              readSessionSnapshot(sessionPath).digest === committed.targetDigest &&
              (existing ? !active : active?.entry.id === transaction.event.id);
            if (!verified) throw new Error("Session reload did not verify the archive transaction");
            removeTransactionBackup(committed.backupPath);
            newCtx.ui.notify(existing ? "Branch restored" : "Branch archived", "info");
          } catch (error) {
            newCtx.ui.notify(error instanceof Error ? error.message : String(error), "error");
          }
        },
      });
      if (switched.cancelled) {
        try {
          rollbackSessionTransaction(snapshot, committed.backupPath, committed.targetDigest);
          ctx.ui.notify("Session switch was cancelled; archive transaction rolled back", "warning");
          return false;
        } catch (rollbackError) {
          ctx.ui.notify(rollbackError instanceof Error ? rollbackError.message : String(rollbackError), "error");
          ctx.shutdown();
          return true;
        }
      }
      return true;
    } catch (error) {
      if (replacementStarted) return true;
      try {
        rollbackSessionTransaction(snapshot, committed.backupPath, committed.targetDigest);
      } catch (rollbackError) {
        ctx.ui.notify(rollbackError instanceof Error ? rollbackError.message : String(rollbackError), "error");
        ctx.shutdown();
        return true;
      }
      throw error;
    }
  } catch (error) {
    if (error instanceof SessionTransactionCommitError) {
      try {
        const backupSnapshot = readSessionSnapshot(error.backupPath);
        rollbackSessionTransaction(
          { ...backupSnapshot, path: sessionPath },
          error.backupPath,
          error.targetDigest,
        );
      } catch (rollbackError) {
        ctx.ui.notify(rollbackError instanceof Error ? rollbackError.message : String(rollbackError), "error");
        ctx.shutdown();
        return true;
      }
    }
    ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
    return false;
  }
}

async function restoreAndNavigate(
  nodeId: string,
  ctx: ExtensionCommandContext,
): Promise<void> {
  const { tree, archived, physicalArchive } = readState(ctx);
  const branch = archived.get(nodeId) ?? findContainingArchivedBranch(nodeId, tree, archived);
  if (!branch) {
    await ctx.navigateTree(nodeId, { summarize: false });
    return;
  }
  if (!physicalArchive || !ctx.isIdle() || ctx.hasPendingMessages()) {
    ctx.ui.notify(
      physicalArchive ? "Wait for the current response and queued messages to finish" : "Archived branch payload is unavailable",
      "warning",
    );
    return;
  }
  const sessionPath = ctx.sessionManager.getSessionFile();
  if (!sessionPath) {
    ctx.ui.notify("Restore requires a persisted session", "error");
    return;
  }

  const targetId =
      nodeId === branch.rootId &&
      tree.nodes.has(branch.resumeId) &&
      isDescendant(tree, branch.rootId, branch.resumeId)
        ? branch.resumeId
        : nodeId;
  try {
    const snapshot = readSessionSnapshot(sessionPath);
    const transaction = buildRestoreTransaction(snapshot, physicalArchive);
    const committed = commitSessionTransaction(snapshot, transaction.bytes);
    let replacementStarted = false;
    try {
      const switched = await ctx.switchSession(sessionPath, {
        withSession: async (newCtx) => {
          replacementStarted = true;
          try {
            const restorePersisted = newCtx.sessionManager
              .getEntries()
              .some((entry) => entry.id === transaction.event.id);
            if (
              readSessionSnapshot(sessionPath).digest !== committed.targetDigest ||
              getActivePhysicalArchive(newCtx.sessionManager.getEntries()) ||
              !restorePersisted
            ) throw new Error("Session reload did not verify the restore transaction");
            removeTransactionBackup(committed.backupPath);
            const result = await newCtx.navigateTree(targetId, { summarize: false });
            if (result.cancelled) {
              newCtx.ui.notify("Branch restored, but navigation was cancelled", "warning");
            }
          } catch (error) {
            newCtx.ui.notify(error instanceof Error ? error.message : String(error), "error");
          }
        },
      });
      if (switched.cancelled) {
        try {
          rollbackSessionTransaction(snapshot, committed.backupPath, committed.targetDigest);
          ctx.ui.notify("Session switch was cancelled; restore transaction rolled back", "warning");
        } catch (rollbackError) {
          ctx.ui.notify(rollbackError instanceof Error ? rollbackError.message : String(rollbackError), "error");
          ctx.shutdown();
        }
      }
    } catch (error) {
      if (!replacementStarted) {
        try {
          rollbackSessionTransaction(snapshot, committed.backupPath, committed.targetDigest);
        } catch (rollbackError) {
          ctx.ui.notify(rollbackError instanceof Error ? rollbackError.message : String(rollbackError), "error");
          ctx.shutdown();
          return;
        }
        throw error;
      }
    }
  } catch (error) {
    if (error instanceof SessionTransactionCommitError) {
      try {
        const backupSnapshot = readSessionSnapshot(error.backupPath);
        rollbackSessionTransaction(
          { ...backupSnapshot, path: sessionPath },
          error.backupPath,
          error.targetDigest,
        );
      } catch (rollbackError) {
        ctx.ui.notify(rollbackError instanceof Error ? rollbackError.message : String(rollbackError), "error");
        ctx.shutdown();
        return;
      }
    }
    ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
  }
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
        const text = extractText(message.content).replace(/[\n\t]+/g, " ").trim();
        return `${message.role}: ${text || "(no content)"}`;
      }
      if (message.role === "toolResult") return `[${message.toolName ?? "tool"}]`;
      if (message.role === "bashExecution") return `[bash] ${message.command ?? ""}`;
      return `[${message.role}]`;
    }
    case "custom_message":
      return `[${entry.customType}] ${extractText(entry.content).replace(/[\n\t]+/g, " ").trim()}`;
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

  constructor(
    private readonly tree: LogicalTree,
    private readonly archived: Map<string, ArchivedBranch>,
    private readonly collapsed: Set<string>,
    selectedId: string | undefined,
    private readonly maxVisibleRows: number,
    private readonly theme: Theme,
    private readonly keybindings: KeybindingsManager,
    private readonly requestRender: () => void,
    private readonly done: (action: ArchiveAction | undefined) => void,
  ) {
    this.selectedId = selectedId ?? findCurrentBranchRoot(tree);
    this.ensureVisibleSelection();
  }

  invalidate(): void {}

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
        visit(
          childId,
          depth + 1,
          index === children.length - 1,
          [...ancestorLast, isLast],
          true,
        ),
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
      (isBranchRoot(this.tree, nodeId) &&
        !findContainingArchivedBranch(nodeId, this.tree, this.archived))
    );
  }

  handleInput(data: string): void {
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
        this.done({ type: "toggle", nodeId: selected.node.entry.id });
        return;
      }
      this.message = "Space is only available on branch roots";
    } else if (this.keybindings.matches(data, "tui.select.confirm")) {
      const selected = this.selectedRow();
      if (selected) {
        this.done({ type: "navigate", nodeId: selected.node.entry.id });
        return;
      }
    } else if (this.keybindings.matches(data, "tui.select.cancel")) {
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
    const lines = [
      this.theme.fg("accent", this.theme.bold("  Archive Branches")),
      "",
    ];

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
      const hidden =
        exactArchive && this.collapsed.has(id)
          ? descendantCount(this.tree, id)
          : 0;
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
    if (this.message) lines.push(truncateToWidth(this.theme.fg("warning", `  ${this.message}`), width, ""));
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
): Promise<ArchiveAction | undefined> {
  return ctx.ui.custom<ArchiveAction | undefined>((tui, theme, keybindings, done) =>
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
    ),
  );
}

export default function archiveExtension(pi: ExtensionAPI): void {
  let archived = new Map<string, ArchivedBranch>();

  pi.on("session_start", async (_event, ctx) => {
    archived = readState(ctx).archived;
  });

  pi.registerCommand("archive", {
    description: "Manage archived conversation branches",
    handler: async (_args, ctx) => {
      if (ctx.mode !== "tui") {
        ctx.ui.notify("/archive requires interactive mode", "error");
        return;
      }

      archived = readState(ctx).archived;
      const collapsed = new Set(archived.keys());
      let selectedId: string | undefined;

      while (true) {
        const state = readState(ctx);
        const tree = state.tree;
        archived = state.archived;
        const action = await showArchiveTree(
          tree,
          archived,
          collapsed,
          selectedId,
          ctx,
        );
        if (!action) return;
        selectedId = action.nodeId;

        if (action.type === "navigate") {
          await restoreAndNavigate(action.nodeId, ctx);
          return;
        }

        // A successful transaction reloads the session and invalidates this
        // command context. Close the picker; users can reopen it if needed.
        if (await toggleArchive(action.nodeId, ctx)) return;
      }
    },
  });
}
