# Agent skills

[Agent Skills specification](https://agentskills.io/specification)

## Authoring conventions

Each skill lives in `<name>/SKILL.md`, with optional supporting files under `scripts/`, `references/`, or `assets/` referenced by relative paths.

### Frontmatter

```markdown
---
name: <skill-name>
description: <What the skill does.> Use when <triggers>, rather than <negative triggers>.
---
```

- `name`: Match the parent directory name (`1–64` characters, lowercase `a-z`, `0-9`, and single hyphens). Use a 1–2 word noun or gerund phrase (at most one hyphen, e.g., `code-reading`, `change-verification`, `failure-diagnosis`, `git-commits`).
- `description`: Write a single-line string (`≤ 1024` characters, target `200–400` characters). Avoid multi-line YAML block scalars (`>` or `|`) that introduce trailing newlines.
- **Routing formula**: Start with an imperative sentence stating what the skill does, followed by a `Use when ..., rather than ...` sentence stating concrete triggers and negative boundaries so the model can distinguish it from adjacent skills.

## Structure and prose

- **Language and clarity**: Write instructions in English following [technical-writing](technical-writing/SKILL.md) (ASD-STE100 principles): use concrete subjects and imperative verbs, express one main idea per sentence, and keep terminology consistent.
- **Density budget**: Target **25–60 lines** and **300–800 words** per `SKILL.md`. Keep one paragraph or bullet per line without hard column wrapping or decorative horizontal rules (`---`). Move large templates, reference tables, or extended examples into `references/`.
- **Information order**: Present each skill in three layers without forcing fixed boilerplate headings (`What` / `Why` / `How`):
  1. **What it is**: State the core purpose or stance in a 1–3 sentence opening paragraph under `# Title`.
  2. **When to use or skip**: Expand on `description` with finer-grained entry, skip, or depth-scaling criteria—inline in the opening paragraph for short skills, or as the first `##` section when scope judgment is complex. Include a brief failure-mode rationale only when it sharpens a constraint; avoid lengthy motivation prose.
  3. **How to apply**: Use flat, imperative `##` sections for the decisions or actions the agent takes instead of nesting everything under a single `## How` heading. For strategy skills, organize by decision points or execution stages; for tool or CLI skills, organize by task workflows, safety guardrails, and post-action verification. State each rule once instead of repeating it across principles, workflow steps, stopping criteria, and anti-pattern lists.
- **Examples**: Give a set of examples a `## Examples` heading with a bold label per example. Put a single illustrative artifact, such as a commit message, in a fenced block under the rule it illustrates. Move extended examples to `references/`.
- **References**: When a skill draws on books, papers, or standards, add a single-line `References:` footer at the end of `SKILL.md` listing only authors and titles (no separate `## References` heading or book summaries). Move detailed datasets, benchmarks, or excerpts into `references/` and link them by relative path.
- **Boundaries**: Keep each skill self-contained. Define adjacent boundaries in `description` by stating what the skill does not cover (negative triggers), without naming other skills.
- **Output discipline**: Global `AGENTS.md` (L0) already forbids exposing internal process labels. Only repeat an explicit reminder in skills with multi-stage frameworks (such as `problem-modeling`) where the model is prone to echoing section headings (`Step 1`, checklist scores, or framework names).
