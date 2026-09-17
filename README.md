# AgentEditor

An English-language macOS app for browsing, editing, and applying agent harness configuration files (`AGENTS.md`, `CLAUDE.md`, rules, and skills) for **Cursor**, **Claude Code**, **Codex**, and **OpenCode**.

Templates live in this repository under `Templates/` so they can be versioned on GitHub and applied into local environments from the app.

## Features

- Switch harness + User/Project scope
- Discover standard instruction / rule / skill paths
- Edit and save files in a plain-text editor (⌘S)
- Browse bundled GitHub-managed AGENT and SKILL libraries
- Switch between AGENT and SKILL, then open a dedicated category and choose a template
- Drag a template onto the environment list to apply it
- Select multiple templates with checkboxes and apply them as a batch
- Preview existing-file conflicts before overwriting
- Move selected instruction files, rules, or complete skill folders to Trash
- Save named instruction + skill sets per harness and restore an earlier set
- Keep project backups isolated by project path and user backups isolated by harness
- Create skills and missing placeholder files
- Work entirely locally without an account or network service

## Template Library

The right pane has two modes: **Templates** and **Backups**. It can be shown or hidden from the toolbar.

In **Templates**, choose a library first:

- **AGENT** — Research, Coding, Finance, and Security
- **SKILL** — Web Design, Coding, Security, Finance, and Legal

Open a category to see its templates. Existing drag-and-drop, individual apply, checkbox selection, batch apply, and overwrite preview flows work from the category detail view.

## Templates layout

```text
Templates/
  catalog.json
  instructions/<id>/template.json + AGENTS.md|CLAUDE.md
  skills/<id>/template.json + <skill-name>/SKILL.md
  rules/<id>/template.json + *.mdc
```

Add new packs in git, then reload templates in the app (or rebuild to refresh the bundle).
Each `template.json` includes a user-facing `category`. Instruction Markdown and rules appear under AGENT; skill folders appear under SKILL.

## Requirements

- macOS 14+
- Xcode 15+

## Build / Run

```bash
cd /path/to/AgentEditor
xcodegen generate
open AgentEditor.xcodeproj
```

Or:

```bash
xcodegen generate
xcodebuild -scheme AgentEditor -configuration Release -derivedDataPath ./DerivedData build
open DerivedData/Build/Products/Release/AgentEditor.app
```

## Apply templates

1. Select a harness and scope (User or Project).
2. Open a project if using Project scope.
3. In the right pane, choose **Templates**, then **AGENT** or **SKILL**.
4. Open a category. Drag a template onto the environment list, apply it from its row, or check several templates and click **Apply Selected**.
5. Confirm overwrite if a destination already exists.

For User scope, instruction templates are written to the harness location that AgentEditor also monitors: `~/.codex/AGENTS.md`, `~/.claude/CLAUDE.md`, or `~/.config/opencode/AGENTS.md`. Cursor loads `AGENTS.md` from a project root, so Cursor instruction templates are marked **Project only** while User scope is selected.

## Remove an active file or skill

Select an existing item in the environment list and use the toolbar trash button, or right-click the row and choose **Move to Trash**. Removing a `SKILL.md` moves its complete skill folder, including scripts and supporting resources, to the macOS Trash after confirmation. Missing placeholders and root skill directories cannot be removed from this action.

## Save and restore a harness set

1. Select the harness and User/Project scope to capture.
2. Open **Backups** in the right pane.
3. Name the current set and click **Save**.
4. Use **Restore** on an earlier set when needed.

A set contains the standard instruction files and complete skill directories for the selected harness and scope. Restoring is exact: managed paths absent from the saved set are removed, and paths present in the set are restored with all skill resources. AgentEditor automatically saves the current set before restoring another one.

Backups remain local under `~/Library/Application Support/AgentEditor/Backups`. Project backups are shown only for the same project path, harness, and scope.

The included focused instruction and audit templates follow the guidance in OpenAI's [Rethinking skills and prompts for GPT-6 Astra](https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra): precise skill triggers, progressive disclosure, contextual documentation, clear decision boundaries, and explicit completion criteria.

## Notes

App Sandbox is disabled so the app can read/write standard home paths such as `~/.cursor` and `~/.claude`. Backups are stored locally as ordinary files; do not include credentials or secrets in instruction and skill files.

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md) for development and template guidelines. Please report sensitive security issues using GitHub private vulnerability reporting as described in [SECURITY.md](SECURITY.md).

AgentEditor is available under the [MIT License](LICENSE).
