import SwiftUI
import UniformTypeIdentifiers

struct FileListView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(spacing: 0) {
            dropBanner
            content
        }
        .navigationTitle(appModel.selectedHarness.displayName)
        .navigationSubtitle(scopeSubtitle)
        .frame(minWidth: 260)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    appModel.requestDeleteSelectedEntry()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(!appModel.canDeleteSelectedEntry)
                .help("Move the selected file or skill to Trash")

                Toggle(isOn: $appModel.showMissingFiles) {
                    Text("Show missing")
                }
                .toggleStyle(.checkbox)
            }
        }
        .onDrop(of: [UTType.plainText, .utf8PlainText], isTargeted: $appModel.isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    @ViewBuilder
    private var dropBanner: some View {
        if appModel.isDropTargeted {
            HStack {
                Image(systemName: "arrow.down.doc.fill")
                Text("Drop to apply template → \(appModel.selectedHarness.displayName) / \(appModel.selectedScope.displayName)")
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(Color.accentColor.opacity(0.15))
        }
    }

    @ViewBuilder
    private var content: some View {
        if appModel.selectedScope == .project && appModel.projectRoot == nil {
            ContentUnavailableView {
                Label("No Project Selected", systemImage: "folder.badge.questionmark")
            } description: {
                Text("Open a project folder from the toolbar to manage project-scoped files.")
            } actions: {
                Button("Open Project…") {
                    appModel.pickProject()
                }
            }
        } else if appModel.visibleGroups.isEmpty {
            ContentUnavailableView {
                Label("No Files", systemImage: "doc.text.magnifyingglass")
            } description: {
                Text(emptyDescription)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(appModel.isDropTargeted ? Color.accentColor : Color.clear, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .padding(8)
            }
        } else {
            List(selection: Binding(
                get: { appModel.selectedEntryID },
                set: { if let id = $0 { appModel.selectEntry(id: id) } }
            )) {
                ForEach(appModel.visibleGroups) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            FileRowView(entry: entry)
                                .tag(entry.id)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        appModel.requestDeleteEntry(entry)
                                    } label: {
                                        Label(deleteLabel(for: entry), systemImage: "trash")
                                    }
                                    .disabled(!entry.exists || entry.isDirectory)
                                }
                        }
                    } header: {
                        Label(group.title, systemImage: group.kind.systemImage)
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    private var scopeSubtitle: String {
        switch appModel.selectedScope {
        case .user:
            return "User / Global"
        case .project:
            if let root = appModel.projectRoot {
                return root.path
            }
            return "Project"
        }
    }

    private var emptyDescription: String {
        switch appModel.selectedScope {
        case .user:
            return "No user-scoped files for this harness yet. Drag a template here to create them."
        case .project:
            return "No project files found. Enable “Show missing” or drag a template here."
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: String.self) { object, _ in
            guard let id = object else { return }
            Task { @MainActor in
                appModel.requestApplyTemplate(id: id)
            }
        }
        return true
    }

    private func deleteLabel(for entry: AgentFileEntry) -> String {
        if entry.kind == .skills && entry.url.lastPathComponent == "SKILL.md" {
            return "Move Skill to Trash"
        }
        return "Move to Trash"
    }
}

private struct FileRowView: View {
    let entry: AgentFileEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(entry.exists ? Color.accentColor : Color.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(rowTitle)
                    .lineLimit(1)
                Text(entry.categoryLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if !entry.exists {
                Text("missing")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            } else if entry.isDirectory {
                Text("dir")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .help(entry.relativeDisplayPath)
    }

    private var rowTitle: String {
        if entry.isDirectory {
            return entry.relativeDisplayPath
        }
        if entry.url.lastPathComponent == "SKILL.md" {
            return entry.url.deletingLastPathComponent().lastPathComponent
        }
        return entry.name
    }

    private var iconName: String {
        if entry.isDirectory { return "folder" }
        switch entry.kind {
        case .instructions: return "doc.plaintext"
        case .rules: return "list.bullet.rectangle"
        case .skills: return "sparkles"
        case .other: return "doc"
        }
    }
}
