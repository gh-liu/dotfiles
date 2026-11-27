# Agent skills

[Agent Skills specification](https://agentskills.io/specification)

## Authoring conventions

Each skill lives in `<name>/SKILL.md`, with optional supporting files under `scripts/`, `references/`, or `assets/` referenced by relative paths.

### Frontmatter

```markdown
---
name: <skill-name>
description: <What the skill does.> Use when <triggers and boundary with adjacent skills>.
---
```

- `name`: Match the parent directory name (`1–64` characters, lowercase `a-z`, `0-9`, and single hyphens). Use a 1–2 word noun or gerund phrase (at most one hyphen, e.g., `code-reading`, `change-verification`, `failure-diagnosis`, `git-commits`).
- `description`: Write a single-line string (`≤ 1024` characters, typically `200–450` characters). Avoid multi-line YAML block scalars (`>` or `|`) that introduce trailing newlines.
- **Routing formula**: Start with an imperative sentence stating what the skill does, followed by a `Use when...` sentence stating concrete triggers and boundaries so the model can distinguish it from adjacent skills.

## Structure and prose

- **Language and clarity**: Write instructions in English following [technical-writing](technical-writing/SKILL.md) (ASD-STE100 principles): use concrete subjects and imperative verbs, express one main idea per sentence, and keep terminology consistent.
- **Density budget**: Target **25–60 lines** and **300–800 words** per `SKILL.md`. Keep one paragraph or bullet per line without hard column wrapping or decorative horizontal rules (`---`). Move large templates, reference tables, or extended examples into `references/`.
- **Information order**: Present each skill in three layers without forcing fixed boilerplate headings (`What` / `Why` / `How`):
  1. **What it is**: State the core purpose or stance in a 1–3 sentence opening paragraph under `# Title`.
  2. **When to use or skip**: Expand on `description` with finer-grained scope, applicability, or skip/exit criteria—inline in the opening paragraph for short skills, or as the first `##` section when scope judgment is complex.
  3. **How to apply**: Use flat, task-oriented `##` sections for the decisions or actions the agent takes instead of nesting everything under a single `## How` heading. State each rule once instead of repeating it across principles, workflow steps, stopping criteria, and anti-pattern lists.
- **Examples**: Give a set of examples a `## Examples` heading with a bold label per example. Put a single illustrative artifact, such as a commit message, in a fenced block under the rule it illustrates. Move extended examples to `references/`.
- **Boundaries**: Keep each skill self-contained. Define adjacent boundaries in `description` by stating what the skill does not cover (negative triggers), without naming other skills.
- **Output discipline**: Global `AGENTS.md` (L0) already forbids exposing internal process labels. Only repeat an explicit reminder in skills with multi-stage frameworks (such as `problem-modeling`) where the model is prone to echoing section headings (`Step 1`, checklist scores, or framework names).
