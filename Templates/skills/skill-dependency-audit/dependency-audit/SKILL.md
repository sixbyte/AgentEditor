---
name: dependency-audit
description: Use when reviewing dependency manifests, lockfiles, package provenance, known vulnerabilities, update risk, or software supply-chain controls.
---

# Dependency Audit

Inspect manifests and lockfiles before running ecosystem audit tools.

- Identify direct, transitive, git, local, and build-time dependencies.
- Verify versions, integrity controls, install scripts, registries, and maintenance status.
- Confirm advisories against the resolved version and reachable usage; avoid severity inflation without exploit context.
- Recommend the least disruptive safe upgrade or replacement and note breaking-change risk.
- Do not modify lockfiles unless remediation is requested.

Report evidence, affected version range, exposure, fix, and validation steps.
