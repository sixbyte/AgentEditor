---
name: pr-description
description: Draft a pull request title, summary, and test plan from the branch diff. Use when the user asks to open or describe a PR.
---

# PR Description

## Steps
1. Inspect commits and diff against the base branch.
2. Capture user intent (why), not only file-level changes (what).
3. Draft:
   - Title
   - Summary bullets (1–3)
   - Test plan checklist

## Output Template
```markdown
## Summary
-

## Test plan
- [ ]
```
