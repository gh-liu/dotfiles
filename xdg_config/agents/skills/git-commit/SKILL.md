---
name: git-commit
description: Create atomic commits, fold follow-up changes into existing local commits, and draft or review commit messages following repository conventions. Use when asked to stage and commit changes, split changes into commits, absorb or fixup changes into local commits, or draft or review a commit message.
---

# Git commits

Follow the repository's contribution guide, commit template, and language conventions. If the user asks only for a draft or review, return the proposed message or review comments.

## Subject format

Check recent commits for the project's subject format and follow it (for example, `scope: subject` or `type(scope): subject`). When the repository uses Conventional Commits, write `type(scope): subject`, choosing a type such as `fix` or `feat` and a scope when it helps identify the affected component. Use a short subject that tells readers what changes.

## Atomic commits

Give each commit one logical purpose. In projects with a build step, the repository must build at every commit in the series. Keep an API change and the caller updates it requires together. A later commit may build on an earlier one.

Use `git status`, `git diff --cached`, and `git diff` to identify the changes. Stage explicit file paths or hunks and preserve the user's staging choices. Never run `git add -A` or `git add .` blindly when untracked, generated, or sensitive files may be present. In non-interactive shells, split hunks with a patch and `git apply --cached` instead of `git add -p`. If the staged changes conflict with the requested scope, clarify the scope first.

Review `git diff --cached` before running `git commit`. Do not bypass hooks with `--no-verify` or run `git commit --amend` unless the user explicitly asks. If a hook rejects a commit, fix the underlying issue and run a new `git commit` instead of amending an earlier one.

When splitting code changes, run the project's applicable checks at each committed snapshot. Build if the project has a build step and run the relevant tests if it has a test suite. Use a temporary clean worktree if pending edits could affect the result, and remove it afterward. If a missing dependency or local configuration prevents a check from running, identify the check and what it requires. Check `git show --stat -1` and `git status --short` to confirm what was committed and what remains.

## Updating local commits

Only rewrite unpushed local commits, and only when the user asks to fold follow-up changes into existing commits instead of adding a new commit. Confirm the local commit range (`git log --oneline <base>..HEAD`) before rewriting history.

- For `HEAD` only: stage the changes and run `git commit --amend` (or `--amend --no-edit` if the message still accurately describes the commit).
- For an earlier local commit: stage the changes, run `git commit --fixup=<sha>`, and fold non-interactively with `GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash <base>`.

When `git-absorb` is installed and staged edits span multiple earlier commits, you may use it to generate `fixup!` commits automatically: preview with `git absorb --dry-run` (pass `--base <ref>` if needed), run `git absorb`, inspect `git log --oneline <base>..HEAD`, and fold with `GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash <base>` (or undo before rebasing with `git reset --soft PRE_ABSORB_HEAD`). Handle any hunks left staged in the index with `git commit --fixup=<sha>` or a new commit, and avoid passing `-w`/`--whole-file` or `-f`/`--force` blindly.

After rewriting commits, re-run the project's applicable build and tests, verify that the updated commit messages still match their diffs, and check `git log --stat <base>..HEAD` and `git status --short`.

## Problem / Solution

A subject alone is enough for a simple change. When the repository has no body template and the motivation needs explaining, draw on the issue, tests, or user-provided context. Choose the format for each section independently. Use prose for one point and a bulleted list for several distinct points about the same change.

- **Problem** describes what happens, under which conditions, and who it affects. For a feature, describe what users previously could not do. Verify that the problem still makes sense if someone chose a different solution.
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
