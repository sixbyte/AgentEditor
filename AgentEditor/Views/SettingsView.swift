import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Form {
            Section("Project") {
                HStack {
                    Text(appModel.projectRoot?.path ?? "None")
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Change…") { appModel.pickProject() }
                    Button("Clear") { appModel.clearProject() }
                        .disabled(appModel.projectRoot == nil)
                }
            }

            Section("Templates Library") {
                Text(appModel.templatesRoot?.path ?? "Not found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                HStack {
                    Button("Choose Templates Folder…") {
                        appModel.pickTemplatesRoot()
                    }
                    Button("Use Bundled / Auto") {
                        appModel.clearTemplatesRootOverride()
                    }
                    Button("Reload") {
                        appModel.refreshTemplates()
                    }
                }
                Text("Keep Templates/ in git so the library can be shared and versioned on GitHub.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Display") {
                Toggle("Show missing files in the environment list", isOn: $appModel.showMissingFiles)
            }

            Section("Harness Paths") {
                ForEach(Harness.allCases) { harness in
                    LabeledContent(harness.displayName) {
                        Text(shortPaths(for: harness))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 480)
        .padding()
    }

    private func shortPaths(for harness: Harness) -> String {
        switch harness {
        case .cursor:
            return "AGENTS.md / .cursor/rules / .cursor/skills"
        case .claude:
            return "CLAUDE.md / .claude/rules / .claude/skills"
        case .codex:
            return "AGENTS.md / ~/.codex / .agents/skills"
        case .openCode:
            return "AGENTS.md / .opencode/skills / ~/.config/opencode"
        }
    }
}
