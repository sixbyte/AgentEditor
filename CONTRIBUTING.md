# Contributing

Contributions are welcome through issues and pull requests.

## Development

Requirements:

- macOS 14 or later
- Xcode 15 or later
- XcodeGen 2.45 or later when changing `project.yml`

Generate and verify the project:

```bash
xcodegen generate
xcodebuild -scheme AgentEditor -configuration Debug -derivedDataPath ./DerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -scheme AgentEditor -configuration Debug -derivedDataPath ./DerivedData CODE_SIGNING_ALLOWED=NO test
```

## Pull requests

- Keep changes focused and describe user-visible behavior.
- Add or update tests for service and model behavior.
- Keep all interface copy in English.
- Never add credentials, machine-specific paths, or generated build output.
- When adding a template, include a unique `template.json` ID and verify every declared harness destination.

## Template guidelines

- Use short, precise names and descriptions.
- Give skills narrow activation conditions in frontmatter.
- Keep the root `SKILL.md` focused; move optional detail into supporting resources.
- Do not claim compatibility that has not been checked against the harness path conventions.
