# Listing saved sessions

Call `list_sessions` directly as a model tool—or from codemode via `tools.list_sessions`—to list sessions for the current working directory,
most recently modified first. The default scope excludes subdirectories.

```js
text(await tools.list_sessions({}));
```

To find sessions across projects, set `currentDirectoryOnly` to `false`.
The optional `query` matches a case-insensitive title substring in either scope.
An empty query or one containing only whitespace matches all titles.

```js
text(await tools.list_sessions({ currentDirectoryOnly: false, query: "migration" }));
```

Each result contains the session `id`, `title`, and absolute JSONL `path`.
The title falls back to the first user message for unnamed sessions. Use `read`
on the path to inspect the session, with `offset` and `limit` for large files.
The file includes all message branches.

The optional `parentSessionId` identifies the originating session, even when
it falls outside the search results. Root sessions and sessions with missing,
unreadable, or malformed parents omit this field.
