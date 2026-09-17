# Security Policy

## Reporting a vulnerability

Please do not open a public issue for a vulnerability that could expose local files, credentials, or destructive file operations. Use GitHub's private vulnerability reporting feature for this repository.

Include the affected version, reproduction steps, expected impact, and any suggested mitigation. Maintainers will acknowledge a complete report as soon as practical and coordinate disclosure after a fix is available.

## Local file access

AgentEditor edits instruction and skill files in user-selected projects and standard harness directories. Review the destination shown in the app before applying templates, especially when overwriting existing content. The app does not upload file contents or require an account.

Named backups are stored unencrypted under `~/Library/Application Support/AgentEditor/Backups`. Treat that directory with the same sensitivity as the instruction and skill files it contains, and never place credentials in harness configuration files.
