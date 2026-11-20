---
name: git-commit
description: Use when the user invokes /commit or asks to commit changes, split changes into commits, or draft or review a commit message. Apply repository conventions, keep commits atomic and buildable, and explain the problem and solution when context is needed.
---

# Git commits

Follow the repository's contribution guide, commit template, and language conventions. If the user asks only for a draft or review, return the proposed message or review comments.

## Conventional Commits

Check recent commits for the project's subject format. When the repository uses Conventional Commits, write `type(scope): subject`. Choose the type that describes the change, such as `fix` or `feat`. Include a scope when it helps identify the affected component. Use a short subject that tells readers what changes.

## Atomic commits

Give each commit one logical purpose. In projects with a build step, the repository must build at every commit in the series. Keep an API change and the caller updates it requires together. A later commit may build on an earlier one.

Use `git status`, `git diff --cached`, and `git diff` to identify the changes. Stage related files or hunks together and preserve the user's staging choices. If the staged changes conflict with the requested scope, clarify the scope first. Review `git diff --cached` before running `git commit`.

For a split series, verify the project build at each committed snapshot. Use a clean worktree if pending edits could affect the result. Check `git show --stat -1` and `git status --short` to confirm what was committed and what remains.

## Problem / Solution

A subject alone is enough for a simple change. When the motivation needs explaining, draw on the issue, tests, or user-provided context. Choose the format for each section independently. Use prose for one point and a bulleted list for several distinct points about the same change.

- **Problem** describes what happens, under which conditions, and who it affects. For a feature, describe what users previously could not do. Would the problem still make sense if someone chose a different solution?
- **Solution** explains how the change addresses that problem. Include implementation details that help readers understand the outcome. Check claims about scope against the diff and performance claims against measurements.

```text
fix(export): preserve leading zeros in account IDs

Problem:
Exporting account ID 00123 produces 123 in the CSV. On import, that row
no longer matches the original account.

Solution:
- Write the account ID to the CSV using its original string value.
- Add a round-trip test that exports and imports account ID 00123.
```
