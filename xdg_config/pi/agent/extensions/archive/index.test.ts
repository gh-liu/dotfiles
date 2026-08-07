import { describe, expect, test } from "bun:test";
import type {
  SessionEntry,
  SessionTreeNode,
} from "@earendil-works/pi-coding-agent";
import {
  buildBranchProjection,
  buildLogicalTree,
  rebuildArchiveState,
} from "./index.ts";

let sequence = 0;

function entry(id: string, parentId: string | null): SessionEntry {
  return {
    type: "session_info",
    id,
    parentId,
    timestamp: new Date(sequence++ * 1_000).toISOString(),
    name: id,
  };
}

function archiveEntry(
  id: string,
  parentId: string | null,
  data: unknown,
): SessionEntry {
  return {
    type: "custom",
    customType: "branch-archive",
    id,
    parentId,
    timestamp: new Date(sequence++ * 1_000).toISOString(),
    data,
  };
}

function node(value: SessionEntry, children: SessionTreeNode[] = []): SessionTreeNode {
  return { entry: value, children };
}

function conversationTree(metadataChildren: SessionTreeNode[] = []): SessionTreeNode[] {
  return [
    node(entry("B", null), [
      node(entry("C", "B"), [
        node(entry("D", "C")),
        node(entry("F", "C")),
      ]),
      node(entry("E", "B"), metadataChildren),
    ]),
  ];
}

describe("logical conversation projection", () => {
  test("contracts archive metadata and maps a metadata leaf to its logical ancestor", () => {
    const metadata = archiveEntry("M", "E", {
      op: "archive",
      rootId: "C",
      resumeId: "D",
      archivedAt: 1,
    });
    const tree = buildLogicalTree(conversationTree([node(metadata)]), "M");

    expect([...tree.nodes.keys()]).toEqual(["B", "C", "D", "F", "E"]);
    expect(tree.nodes.get("E")?.children).toEqual([]);
    expect(tree.physicalToLogical.get("M")).toBe("E");
    expect(tree.leafId).toBe("E");
  });

  test("projects non-metadata descendants through metadata nodes", () => {
    const metadata = archiveEntry("M", "E", {
      op: "restore",
      rootId: "C",
      restoredAt: 2,
    });
    const child = node(entry("G", "M"));
    const tree = buildLogicalTree(conversationTree([node(metadata, [child])]), "G");

    expect(tree.nodes.get("G")?.parentId).toBe("E");
    expect(tree.nodes.get("E")?.children).toEqual(["G"]);
    expect(tree.leafId).toBe("G");
  });

  test("archive projection contains branch roots instead of every message", () => {
    const tree = buildLogicalTree(conversationTree(), "F");
    const projection = buildBranchProjection(tree);

    expect(projection.roots).toEqual(["C", "E"]);
    expect(projection.children.get("C")).toEqual(["D", "F"]);
    expect([...projection.roots, ...[...projection.children.values()].flat()]).toEqual(
      ["C", "E", "D", "F"],
    );
    expect(tree.nodes.size).toBe(5);
  });
});

describe("archive event replay", () => {
  test("replays archive and restore events in append order", () => {
    const tree = buildLogicalTree(conversationTree(), "E");
    const entries = [
      archiveEntry("M1", "E", {
        op: "archive",
        version: 1,
        rootId: "C",
        resumeId: "D",
        archivedAt: 1,
      }),
      archiveEntry("M2", "M1", {
        op: "restore",
        version: 1,
        rootId: "C",
        restoredAt: 2,
      }),
      archiveEntry("M3", "M2", {
        op: "archive",
        version: 1,
        rootId: "E",
        resumeId: "E",
        archivedAt: 3,
      }),
    ];

    expect([...rebuildArchiveState(entries, tree).keys()]).toEqual(["E"]);
  });

  test("normalizes nested archived roots to an antichain", () => {
    const tree = buildLogicalTree(conversationTree(), "E");
    const entries = [
      archiveEntry("M1", "E", {
        op: "archive",
        version: 1,
        rootId: "D",
        resumeId: "D",
        archivedAt: 1,
      }),
      archiveEntry("M2", "M1", {
        op: "archive",
        version: 1,
        rootId: "C",
        resumeId: "F",
        archivedAt: 2,
      }),
    ];

    expect([...rebuildArchiveState(entries, tree).keys()]).toEqual(["C"]);
  });

  test("ignores malformed, stale, and non-branch archive events", () => {
    const tree = buildLogicalTree(conversationTree(), "E");
    const entries = [
      archiveEntry("M1", "E", { op: "archive", version: 1, rootId: "C" }),
      archiveEntry("M2", "M1", {
        op: "archive",
        version: 1,
        rootId: "missing",
        resumeId: "missing",
        archivedAt: 1,
      }),
      archiveEntry("M3", "M2", {
        op: "archive",
        version: 1,
        rootId: "C",
        resumeId: "E",
        archivedAt: 2,
      }),
      archiveEntry("M4", "M3", {
        op: "archive",
        version: 1,
        rootId: "B",
        resumeId: "B",
        archivedAt: 3,
      }),
    ];

    expect(rebuildArchiveState(entries, tree).size).toBe(0);
  });

  test("ignores legacy metadata-only archive events", () => {
    const tree = buildLogicalTree(conversationTree(), "E");
    const entries = [
      archiveEntry("M1", "E", {
        op: "archive",
        rootId: "C",
        resumeId: "D",
        archivedAt: 1,
      }),
    ];

    expect(rebuildArchiveState(entries, tree).size).toBe(0);
  });
});
