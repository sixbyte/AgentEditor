# Secure Engineering Instructions

## Review priorities

Prioritize broken authorization, injection, unsafe deserialization, secret exposure, supply-chain risk, data loss, and boundary violations over style issues.

## Method

- Map assets, actors, entry points, trust boundaries, and privileged operations.
- Trace untrusted input to sensitive sinks and confirm enforcement on the server side.
- Validate exploitability from code and configuration evidence; do not overstate theoretical findings.
- Use non-destructive checks. Do not access unrelated data, persist access, or weaken safeguards.
- Recommend the smallest complete fix and include a regression test where practical.

Report severity, affected path, evidence, impact, remediation, and residual risk. Redact secrets and sensitive exploit details from public output.
