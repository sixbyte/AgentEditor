# Templates

Bundled instruction and skill templates for AgentEditor.

## Layout

```text
Templates/
  catalog.json
  instructions/          # AGENT library: AGENTS.md / CLAUDE.md packs
    <template-id>/
      template.json
      AGENTS.md | CLAUDE.md
  skills/                # SKILL library: complete SKILL.md folders
    <template-id>/
      template.json
      <skill-name>/
        SKILL.md
  rules/                 # Optional rule packs (.mdc / .md)
    <template-id>/
      template.json
      *.mdc | *.md
```

## `template.json`

```json
{
  "id": "agents-basic",
  "name": "Basic AGENTS.md",
  "description": "Minimal project instructions",
  "category": "Coding",
  "kind": "instructions",
  "targetFileName": "AGENTS.md",
  "compatibleHarnesses": ["cursor", "codex", "openCode", "claude"],
  "tags": ["starter"]
}
```

Use `category` for the user-facing group in the Templates pane. AGENT categories are Research, Coding, Finance, and Security. SKILL categories are Web Design, Coding, Security, Finance, and Legal. Rules are shown in the AGENT library so the existing rule workflow remains available. For skills, set `"kind": "skills"` and include a complete skill folder containing `SKILL.md` and any optional resources.

## Using in the app

1. Open **Templates** in the right pane and choose **AGENT** or **SKILL**.
2. Open a category, then drag one template onto the environment list or select several checkboxes.
3. Choose **Apply Selected**. AgentEditor previews conflicts and copies the content into the standard path for the current harness and scope.

Keep names and descriptions specific. A skill description should state the workflow that activates it without claiming broad adjacent topics. Put optional detail in references or scripts so agents load it only when needed.
