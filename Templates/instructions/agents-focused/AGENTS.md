# Project Instructions

## Project context

- Product: Describe the user-facing purpose in one sentence.
- Stack: List the languages, frameworks, and package manager actually used here.
- Important paths: Name only the directories that are useful across many tasks.

## Task-specific references

- Read `architecture.md` when changing service boundaries or shared interfaces.
- Read `database.md` when changing schemas, migrations, or persistence behavior.
- Read `deployment.md` when preparing a release or changing production infrastructure.

Do not load every reference for routine edits. Inspect the files that are relevant to the current task.

## Commands

- Build: `<build command>`
- Test: `<test command>`
- Lint or typecheck: `<validation command>`

The local test suite uses disposable fixtures and has no production access. Run affected tests, fix failures caused by the requested change, and rerun those tests without requesting confirmation at each step.

## Working style

- Infer routine details from nearby code and existing conventions.
- Keep changes within the requested scope and preserve unrelated work.
- Prefer the smallest complete implementation over speculative abstractions.
- Use clear, concise prose and lead with the outcome.
- Stop and ask before destructive operations, production changes, spending money, or actions that affect external users.

## Completion

A task is complete when the requested behavior is implemented, relevant checks pass, and the result is summarized with any remaining validation limits. Do not stop after the first draft when safe local verification or an obvious in-scope fix remains.

## Skills

- Use a skill only when its description clearly matches the current task.
- The user's explicit instructions take precedence over general skill guidance.
- If a skill changes the approach or prevents completion, identify the skill and explain why.
