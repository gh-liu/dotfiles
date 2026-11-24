---
description: Restate requirements, constraints/invariants, and current approach, surfacing open questions
argument-hint: "[focus, scope, or new context]"
---

Based on the discussion, decisions, and evidence gathered so far—incorporating any new input below—restate concisely where the task stands so a human reader can grasp current alignment and open forks at a glance.

Focus, scope, or new context: ${@:-none}

Write in plain, natural engineering prose (adapting headings to the conversation's language rather than copying template labels verbatim, and avoiding raw code, schema, or field dumps unless a specific detail is itself in question):

- **Requirements & non-goals:** Lead with a one- or two-sentence status snapshot, then state the needed outcome, observable acceptance criteria, and what is explicitly out of scope.
- **Constraints & invariants:** Hard limits the solution must respect (including relevant active ADRs) and existing behaviors, contracts, or state properties that must remain unchanged.
- **Current approach:** How the agreed direction (or active candidate options) meets those requirements while preserving invariants—clearly separating agreed decisions from open proposals (noting anything superseded) and verified facts from unverified assumptions.
- **Open questions & decisions needed** *(omit if none)*: Only high-impact ambiguities, unstated boundaries, or unresolved trade-offs that would change scope, outcome, or approach—proposing sensible defaults for low-risk reversible choices and stating what concrete check would settle open trade-offs.

Summarize current understanding only: do not modify files or state, and do not start new investigation unless needed to verify a cited reference.
