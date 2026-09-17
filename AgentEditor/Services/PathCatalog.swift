import Foundation

/// Catalog of standard paths each agent harness discovers by default.
enum PathCatalog {
    struct Target {
        let relativePath: String
        let kind: FileKind
        let categoryLabel: String
        let isDirectory: Bool
        /// When true, recursively collect editable files under the directory.
        let expandFiles: Bool
        /// Optional filename patterns when expanding (e.g. SKILL.md, *.mdc).
        let filePatterns: [String]
    }

    static func userTargets(for harness: Harness) -> [Target] {
        switch harness {
        case .cursor:
            return [
                Target(
                    relativePath: ".cursor/rules",
                    kind: .rules,
                    categoryLabel: "User Rules (~/.cursor/rules)",
                    isDirectory: true,
                    expandFiles: true,
                    filePatterns: ["*.mdc", "*.md"]
                ),
                Target(
                    relativePath: ".cursor/skills",
                    kind: .skills,
                    categoryLabel: "User Skills (~/.cursor/skills)",
                    isDirectory: true,
                    expandFiles: true,
                    filePatterns: ["SKILL.md", "*.md"]
                ),
                Target(
                    relativePath: ".agents/skills",
                    kind: .skills,
                    categoryLabel: "Shared Skills (~/.agents/skills)",
                    isDirectory: true,
                    expandFiles: true,
                    filePatterns: ["SKILL.md", "*.md"]
                ),
            ]
        case .claude:
            return [
                Target(
                    relativePath: ".claude/CLAUDE.md",
                    kind: .instructions,
                    categoryLabel: "User Instructions",
                    isDirectory: false,
                    expandFiles: false,
                    filePatterns: []
                ),
                Target(
                    relativePath: ".claude/rules",
                    kind: .rules,
                    categoryLabel: "User Rules (~/.claude/rules)",
                    isDirectory: true,
                    expandFiles: true,
                    filePatterns: ["*.md"]
                ),
                Target(
                    relativePath: ".claude/skills",
                    kind: .skills,
                    categoryLabel: "User Skills (~/.claude/skills)",
                    isDirectory: true,
                    expandFiles: true,
                    filePatterns: ["SKILL.md", "*.md"]
                ),
            ]
        case .codex:
            return [
                Target(
                    relativePath: ".codex/AGENTS.md",
                    kind: .instructions,
                    categoryLabel: "User Instructions",
                    isDirectory: false,
                    expandFiles: false,
                    filePatterns: []
                ),
                Target(
                    relativePath: ".codex/AGENTS.override.md",
                    kind: .instructions,
                    categoryLabel: "User Override",
                    isDirectory: false,
                    expandFiles: false,
                    filePatterns: []
                ),
                Target(
                    relativePath: ".agents/skills",
                    kind: .skills,
                    categoryLabel: "User Skills (~/.agents/skills)",
                    isDirectory: true,
                    expandFiles: true,
                    filePatterns: ["SKILL.md", "*.md"]
                ),
                Target(
                    relativePath: ".codex/skills",
                    kind: .skills,
                    categoryLabel: "Legacy Skills (~/.codex/skills)",
                    isDirectory: true,
                    expandFiles: true,
                    filePatterns: ["SKILL.md", "*.md"]
                ),
            ]
        case .openCode:
            return [
                Target(
                    relativePath: ".config/opencode/AGENTS.md",
                    kind: .instructions,
                    categoryLabel: "User Instructions",
                    isDirectory: false,
                    expandFiles: false,
                    filePatterns: []
                ),
                Target(
                    relativePath: ".config/opencode/skills",
                    kind: .skills,
                    categoryLabel: "User Skills (~/.config/opencode/skills)",
                    isDirectory: true,
                    expandFiles: true,
                    filePatterns: ["SKILL.md", "*.md"]
                ),
            ]
        }
    }

    static func projectTargets(for harness: Harness) -> [Target] {
        switch harness {
        case .cursor:
            return [
                Target(
                    relativePath: "AGENTS.md",
                    kind: .instructions,
                    categoryLabel: "AGENTS.md",
                    isDirectory: false,
                    expandFiles: false,
                    filePatterns: []
                ),
                Target(
                    relativePath: "CLAUDE.md",
                    kind: .instructions,
                    categoryLabel: "CLAUDE.md (compat)",
                    isDirectory: false,
                    expandFiles: false,
                    filePatterns: []
                ),
                Target(
                    relativePath: ".cursor/rules",
                    kind: .rules,
                    categoryLabel: "Project Rules (.cursor/rules)",
                    isDirectory: true,
                    expandFiles: true,
                    filePatterns: ["*.mdc", "*.md"]
                ),
                Target(
                    relativePath: ".cursor/skills",
                    kind: .skills,
                    categoryLabel: "Project Skills (.cursor/skills)",
                    isDirectory: true,
                    expandFiles: true,
                    filePatterns: ["SKILL.md", "*.md"]
                ),
                Target(
                    relativePath: ".agents/skills",
                    kind: .skills,
                    categoryLabel: "Shared Skills (.agents/skills)",
                    isDirectory: true,
                    expandFiles: true,
                    filePatterns: ["SKILL.md", "*.md"]
                ),
            ]
        case .claude:
            return [
                Target(
                    relativePath: "CLAUDE.md",
                    kind: .instructions,
                    categoryLabel: "CLAUDE.md",
                    isDirectory: false,
                    expandFiles: false,
                    filePatterns: []
                ),
                Target(
                    relativePath: ".claude/CLAUDE.md",
                    kind: .instructions,
                    categoryLabel: ".claude/CLAUDE.md",
                    isDirectory: false,
                    expandFiles: false,
                    filePatterns: []
                ),
                Target(
                    relativePath: ".claude/rules",
                    kind: .rules,
                    categoryLabel: "Project Rules (.claude/rules)",
                    isDirectory: true,
                    expandFiles: true,
                    filePatterns: ["*.md"]
                ),
                Target(
                    relativePath: ".claude/skills",
                    kind: .skills,
                    categoryLabel: "Project Skills (.claude/skills)",
                    isDirectory: true,
                    expandFiles: true,
                    filePatterns: ["SKILL.md", "*.md"]
                ),
            ]
        case .codex:
            return [
                Target(
                    relativePath: "AGENTS.md",
                    kind: .instructions,
                    categoryLabel: "AGENTS.md",
                    isDirectory: false,
                    expandFiles: false,
                    filePatterns: []
                ),
                Target(
                    relativePath: "AGENTS.override.md",
                    kind: .instructions,
                    categoryLabel: "AGENTS.override.md",
                    isDirectory: false,
                    expandFiles: false,
                    filePatterns: []
                ),
                Target(
                    relativePath: ".agents/skills",
                    kind: .skills,
                    categoryLabel: "Project Skills (.agents/skills)",
                    isDirectory: true,
                    expandFiles: true,
                    filePatterns: ["SKILL.md", "*.md"]
                ),
            ]
        case .openCode:
            return [
                Target(
                    relativePath: "AGENTS.md",
                    kind: .instructions,
                    categoryLabel: "AGENTS.md",
                    isDirectory: false,
                    expandFiles: false,
                    filePatterns: []
                ),
                Target(
                    relativePath: ".opencode/skills",
                    kind: .skills,
                    categoryLabel: "Project Skills (.opencode/skills)",
                    isDirectory: true,
                    expandFiles: true,
                    filePatterns: ["SKILL.md", "*.md"]
                ),
                Target(
                    relativePath: ".agents/skills",
                    kind: .skills,
                    categoryLabel: "Shared Skills (.agents/skills)",
                    isDirectory: true,
                    expandFiles: true,
                    filePatterns: ["SKILL.md", "*.md"]
                ),
            ]
        }
    }
}
