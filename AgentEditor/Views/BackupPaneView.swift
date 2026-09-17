import SwiftUI

struct BackupPaneView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            saveForm
            backupsList
        }
        .onAppear {
            appModel.refreshBackups()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Saved Sets")
                .font(.headline)
            Spacer()
            Text("\(appModel.selectedHarness.displayName) · \(appModel.selectedScope.displayName)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Button {
                appModel.refreshBackups()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Reload backups")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(height: 44)
    }

    private var saveForm: some View {
        HStack {
            TextField("Backup name", text: $appModel.backupName)
                .textFieldStyle(.roundedBorder)
                .help("Name and save the current instruction and skill set")
            Button("Save") {
                appModel.saveNamedBackup()
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                appModel.backupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || (appModel.selectedScope == .project && appModel.projectRoot == nil)
            )
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var backupsList: some View {
        if appModel.selectedScope == .project && appModel.projectRoot == nil {
            ContentUnavailableView {
                Label("No Project Selected", systemImage: "folder.badge.questionmark")
            } description: {
                Text("Open a project to save or restore its harness set.")
            }
        } else if appModel.backups.isEmpty {
            ContentUnavailableView {
                Label("No Saved Sets", systemImage: "archivebox")
            } description: {
                Text("Name the current set and save it for later restoration.")
            }
        } else {
            List(appModel.backups) { backup in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(backup.name)
                            .font(.body)
                            .lineLimit(1)
                        Spacer()
                        Button("Restore") {
                            appModel.requestRestoreBackup(backup)
                        }
                        .buttonStyle(.borderless)
                    }
                    Text(backup.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label(
                        "\(backup.presentItemCount) saved \(backup.presentItemCount == 1 ? "location" : "locations")",
                        systemImage: "doc.on.doc"
                    )
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 3)
                .help(backup.manifest.sourceRootPath)
            }
            .listStyle(.sidebar)
        }
    }
}
