---
name: instruction-audit
description: Audit agent instructions and skill files for stale, conflicting, overly broad, or context-heavy guidance. Use when reviewing AGENTS.md, CLAUDE.md, rules, or SKILL.md files.
---

# Instruction Audit

Review only active, first-party instruction files. Exclude generated outputs, dependencies, caches, and vendored copies.

## Review

1. Inventory the instruction files and skill entry points used by the selected harness.
2. Flag guidance that is stale, duplicated, contradictory, or broader than its real workflow.
3. Check every skill description for a precise trigger. It should explain when the skill applies without claiming adjacent tasks.
4. Prefer progressive disclosure: keep the root `SKILL.md` short and route optional workflows to supporting references or scripts.
5. Replace unconditional reading with contextual pointers to the relevant documentation.
6. Make safe autonomy, approval boundaries, and the definition of completion explicit.
7. Recommend deletion when general model behavior already covers an instruction reliably.

## Output

Report findings in priority order. For each finding, name the file, quote only the necessary fragment, explain its effect, and propose concise replacement text. Separate confirmed issues from suggestions that require repository context.
