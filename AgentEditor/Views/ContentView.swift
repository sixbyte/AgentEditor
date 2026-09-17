import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @AppStorage("AgentEditor.showTemplatesPane") private var showLibraryPane = true
    @State private var newSkillName = ""
    @State private var showNewSkillSheet = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } content: {
            FileListView()
                .frame(minWidth: 260)
        } detail: {
            HSplitView {
                EditorPaneView()
                    .frame(minWidth: 420)

                if showLibraryPane {
                    LibraryPaneView()
                        .frame(minWidth: 240, idealWidth: 300, maxWidth: 380)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.2), value: showLibraryPane)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Picker("Scope", selection: Binding(
                    get: { appModel.selectedScope },
                    set: { appModel.changeScope($0) }
                )) {
                    ForEach(FileScope.allCases) { scope in
                        Text(scope.displayName).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if appModel.selectedScope == .project {
                    Button {
                        appModel.pickProject()
                    } label: {
                        Label(projectLabel, systemImage: "folder")
                    }
                }

                Button {
                    appModel.refreshTemplates()
                    appModel.refresh()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }

                Button {
                    showNewSkillSheet = true
                } label: {
                    Label("New Skill", systemImage: "plus")
                }

                Button {
                    showLibraryPane.toggle()
                } label: {
                    Label(
                        showLibraryPane ? "Hide Library" : "Show Library",
                        systemImage: "sidebar.right"
                    )
                }
                .help(showLibraryPane ? "Hide Templates and Backups" : "Show Templates and Backups")

                Button {
                    appModel.saveCurrentFile()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .disabled(!appModel.canSave)
            }
        }
        .safeAreaInset(edge: .bottom) {
            StatusBarView()
        }
        .sheet(isPresented: $showNewSkillSheet) {
            NewSkillSheet(name: $newSkillName) {
                appModel.createSkill(named: newSkillName)
                newSkillName = ""
                showNewSkillSheet = false
            } onCancel: {
                newSkillName = ""
                showNewSkillSheet = false
            }
        }
        .alert("Error", isPresented: Binding(
            get: { appModel.errorMessage != nil },
            set: { if !$0 { appModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                appModel.errorMessage = nil
            }
        } message: {
            Text(appModel.errorMessage ?? "")
        }
        .confirmationDialog(
            "Unsaved Changes",
            isPresented: Binding(
                get: { appModel.pendingNavigation != nil },
                set: { if !$0 { appModel.cancelPendingNavigation() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Save and Continue") {
                appModel.saveAndContinuePending()
            }
            Button("Discard Changes", role: .destructive) {
                appModel.confirmDiscardPending()
            }
            Button("Cancel", role: .cancel) {
                appModel.cancelPendingNavigation()
            }
        } message: {
            Text("Save or discard your edits before continuing.")
        }
        .confirmationDialog(
            "Overwrite Existing Files?",
            isPresented: Binding(
                get: { appModel.pendingTemplateApply != nil },
                set: { if !$0 { appModel.cancelTemplateApply() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Overwrite") {
                if let ids = appModel.pendingTemplateApply?.templateIDs {
                    appModel.applyTemplates(ids: ids, overwrite: true)
                }
            }
            Button("Cancel", role: .cancel) {
                appModel.cancelTemplateApply()
            }
        } message: {
            Text(overwriteMessage)
        }
        .confirmationDialog(
            "Restore Backup?",
            isPresented: Binding(
                get: { appModel.pendingBackupRestore != nil },
                set: { if !$0 { appModel.cancelBackupRestore() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Restore Backup", role: .destructive) {
                appModel.restorePendingBackup()
            }
            Button("Cancel", role: .cancel) {
                appModel.cancelBackupRestore()
            }
        } message: {
            Text(restoreMessage)
        }
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: Binding(
                get: { appModel.pendingFileDeletion != nil },
                set: { if !$0 { appModel.cancelFileDeletion() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                appModel.confirmFileDeletion()
            }
            Button("Cancel", role: .cancel) {
                appModel.cancelFileDeletion()
            }
        } message: {
            Text(deleteMessage)
        }
    }

    private var projectLabel: String {
        if let root = appModel.projectRoot {
            return root.lastPathComponent
        }
        return "Project"
    }

    private var overwriteMessage: String {
        if let pending = appModel.pendingTemplateApply {
            let count = pending.templateIDs.count
            let noun = count == 1 ? "template" : "templates"
            return "Existing content was found at \(pending.destinationHint). Overwrite it while applying \(count) \(noun)?"
        }
        return "Destination files already exist."
    }

    private var restoreMessage: String {
        guard let backup = appModel.pendingBackupRestore else {
            return "The current instruction and skill set will be replaced."
        }
        return "“\(backup.name)” will replace the current instruction and skill set for \(appModel.selectedHarness.displayName). A safety backup of the current set will be created first."
    }

    private var deleteDialogTitle: String {
        guard let pending = appModel.pendingFileDeletion else { return "Move to Trash?" }
        return pending.deletesSkillFolder ? "Move Skill to Trash?" : "Move File to Trash?"
    }

    private var deleteMessage: String {
        guard let pending = appModel.pendingFileDeletion else {
            return "The selected item will be moved to Trash."
        }
        let unsavedWarning = appModel.isDirty && appModel.selectedEntryID == pending.entry.id
            ? " Unsaved editor changes will be discarded."
            : ""
        if pending.deletesSkillFolder {
            return "“\(pending.displayName)” and all files in its skill folder will be moved to Trash.\(unsavedWarning)"
        }
        return "“\(pending.entry.relativeDisplayPath)” will be moved to Trash.\(unsavedWarning)"
    }
}

private struct NewSkillSheet: View {
    @Binding var name: String
    let onCreate: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Skill")
                .font(.headline)
            Text("Creates a SKILL.md folder in the standard skills path for the selected harness and scope.")
                .foregroundStyle(.secondary)
                .font(.callout)
            TextField("skill-name", text: $name)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Create", action: onCreate)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
