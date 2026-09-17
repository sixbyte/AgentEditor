# TypeScript Project Instructions

## Stack
- Language: TypeScript
- Package manager: (npm / pnpm / yarn / bun)
- Test runner: (vitest / jest / node:test)

## Commands
- Install: `pnpm install`
- Dev: `pnpm dev`
- Build: `pnpm build`
- Test: `pnpm test`
- Typecheck: `pnpm typecheck`

## Conventions
- Prefer `async`/`await` over raw promises.
- Keep modules small; export explicit public APIs.
- Avoid `any`; use `unknown` and narrow.
- Colocate tests next to source or under `__tests__` as the repo already does.

## Agent Behavior
- Run typecheck/tests after non-trivial changes when feasible.
- Do not introduce new dependencies unless necessary.
- Preserve existing formatting and lint rules.
