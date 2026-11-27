---
name: git-commits
description: Create atomic commits, fold follow-up edits into local commits, and draft or review commit messages following repository conventions. Use when staging and committing changes, splitting commits, absorbing or fixing up local commits, or drafting or reviewing commit messages, rather than for code reviews, pull request descriptions, or branch and worktree management.
---

# Git commits

Keep git history reviewable and consistent with the repository's contribution guide, commit template, and language conventions. When asked only to draft or review a commit message, return the message or comments without running git mutations; follow the commit or local-rewrite workflows below only when asked to commit or update local commits.

## Write clear commit messages

Match the subject format used in recent commits (for example, `scope: subject` or `type(scope): subject`). For Conventional Commits, pick a type such as `fix` or `feat` and a scope that identifies the affected component. Write the subject in imperative mood (completing *"If applied, this commit will `<subject>`"*), keep it concise (around 50 characters, no trailing period), and separate subject from body with a blank line.

A subject alone suffices for a simple change. When the repository has no body template and the motivation needs explaining, explain *what* and *why* rather than restating *how* the diff works, drawing on the issue, tests, or user-provided context. Use prose for one point and bullets for several distinct points:

- **Problem** describes what happens, under which conditions, and who it affects (for a feature, what users previously could not do). Verify that the problem still makes sense under a different solution.
- **Solution** explains how the change addresses that problem, checking scope claims against the diff and performance claims against measurements.

```text
fix(export): preserve leading zeros in account IDs

Problem:
Exporting account ID 00123 produces 123 in the CSV. On import, that row
no longer matches the original account.

Solution:
- Write the account ID to the CSV using its original string value.
- Add a round-trip test that exports and imports account ID 00123.
```

## Keep commits atomic

- Give each commit one logical purpose and never tangle unrelated tasks (such as a bug fix with an unrelated refactor), so code review, `git revert`, and `git bisect` stay reliable. Keep the repository building at every commit, pairing an API change with its required caller updates.
- Inspect changes with `git status`, `git diff --cached`, and `git diff`. Stage explicit paths or hunks while preserving the user's staging choices; never run `git add -A` or `git add .` blindly when untracked, generated, or sensitive files may exist. In non-interactive shells, split hunks with a patch and `git apply --cached` instead of `git add -p`. If staged changes conflict with the requested scope, clarify first.
- Review `git diff --cached` before committing. Never bypass hooks with `--no-verify` or run `git commit --amend` unless explicitly asked. If a hook rejects a commit, inspect its output: fix and re-stage in-scope causes, or report the blocking hook and reason.
- When splitting code changes, run applicable build and test checks at each committed snapshot—using a temporary clean worktree if pending edits could affect results, then removing it. If missing dependencies or configuration block a check, report what is missing. Confirm results with `git show --stat -1` and `git status --short`.

## Update unpushed local commits

Only rewrite unpushed local commits when asked to fold follow-up edits into existing commits. Inspect targets first (`git log --oneline <base>..HEAD` or `-n 1 HEAD`). Stop before rewriting if any target is a merge (`git rev-list --merges <base>..HEAD` or `--no-walk --merges HEAD`) or appears in `git branch -r --contains <sha>` across fetched `refs/remotes/*` refs (not only `@{u}`). Confirm first when a configured remote has missing or stale tracking refs.

- **`HEAD` only:** Stage the changes and run `git commit --amend` (or `--amend --no-edit` if the message still matches).
- **Earlier local commit:** Stage the changes, run `git commit --fixup=<sha>`, and fold non-interactively with `GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash <base>`.
- **Multiple earlier commits with `git-absorb`:** Preview with `git absorb --dry-run` (pass `--base <ref>` if needed) and run `git absorb` without blind `-w`/`--whole-file` or `-f`/`--force`. Check `git log --oneline <base>..HEAD` and `git status --short` (undo before rebasing via `git reset --soft PRE_ABSORB_HEAD`). Convert remaining staged hunks for earlier commits with `git commit --fixup=<sha>`, unstage or commit the rest so the index is clean, then fold with `GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash <base>`.

If a rebase conflicts, run `git rebase --abort`, report the conflicting commit, and confirm instead of force-resolving.

After rewriting commits, re-run applicable build and test checks, confirm updated messages still match their diffs, and check `git log --stat <base>..HEAD` and `git status --short`.

References: Chris Beams, *How to Write a Git Commit Message*; Scott Chacon and Ben Straub, *Pro Git*; Kim Herzig and Andreas Zeller, *The Impact of Tangled Code Changes* (MSR 2013).
