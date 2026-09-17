---
name: commit-message
description: Draft a clear conventional commit message from staged or unstaged changes. Use when the user asks for a commit message or commit help.
---

# Commit Message

## Steps
1. Inspect `git status` and `git diff` (staged preferred, otherwise unstaged).
2. Infer intent: feat / fix / refactor / docs / test / chore.
3. Write a subject line ≤ 72 characters, imperative mood.
4. Add a short body only when useful (why, not how).
5. Avoid vague subjects like "update" or "fix stuff".

## Output Format
```text
<type>(optional-scope): <subject>

Optional body.
```
