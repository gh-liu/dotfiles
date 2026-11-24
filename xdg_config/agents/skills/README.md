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

- `name`: Match the parent directory name (`1–64` characters, lowercase `a-z`, `0-9`, and single hyphens).
- `description`: Write a single-line string (`≤ 1024` characters, typically `200–450` characters). Avoid multi-line YAML block scalars (`>` or `|`) that introduce trailing newlines.
- **Routing formula**: Start with an imperative sentence stating what the skill does, followed by a `Use when...` sentence stating concrete triggers and boundaries so the model can distinguish it from adjacent skills.

## Structure and prose

- **Language and clarity**: Write instructions in English following [technical-writing](technical-writing/SKILL.md) (ASD-STE100 principles): use concrete subjects and imperative verbs, express one main idea per sentence, and keep terminology consistent.
- **Density budget**: Target **25–60 lines** and **300–800 words** per `SKILL.md`. Keep one paragraph or bullet per line without hard column wrapping or decorative horizontal rules (`---`). Move large templates, reference tables, or extended examples into `references/`.
- **Task-oriented sections**: Organize `##` headings around the decisions or actions the agent takes. State each rule once instead of repeating it across principles, workflow steps, stopping criteria, and anti-pattern lists.
- **Examples**: Give a set of examples a `## Examples` heading with a bold label per example. Put a single illustrative artifact, such as a commit message, in a fenced block under the rule it illustrates. Move extended examples to `references/`.
- **Boundaries**: Keep each skill self-contained. Define adjacent boundaries in `description` by stating what the skill does not cover (negative triggers), without naming other skills.
- **Output discipline**: Global `AGENTS.md` (L0) already forbids exposing internal process labels. Only repeat an explicit reminder in skills with multi-stage frameworks (such as `problem-modeling`) where the model is prone to echoing section headings (`Step 1`, checklist scores, or framework names).
