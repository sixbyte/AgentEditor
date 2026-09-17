import Foundation

struct AgentBackupItem: Codable, Hashable {
    let relativePath: String
    let kind: FileKind
    let wasPresent: Bool
    let isDirectory: Bool
}

struct AgentBackupManifest: Codable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let harness: Harness
    let scope: FileScope
    let sourceRootPath: String
    let createdAt: Date
    let items: [AgentBackupItem]
}

struct AgentBackup: Identifiable, Hashable {
    let manifest: AgentBackupManifest
    let rootURL: URL

    var id: UUID { manifest.id }
    var name: String { manifest.name }
    var createdAt: Date { manifest.createdAt }

    var presentItemCount: Int {
        manifest.items.filter(\.wasPresent).count
    }
}
