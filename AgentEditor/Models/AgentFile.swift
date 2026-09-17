import Foundation

struct AgentFileEntry: Identifiable, Hashable {
    let id: String
    let url: URL
    let harness: Harness
    let scope: FileScope
    let kind: FileKind
    let categoryLabel: String
    let exists: Bool
    let isDirectory: Bool

    var name: String { url.lastPathComponent }

    var relativeDisplayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

struct FileGroup: Identifiable, Hashable {
    let id: String
    let kind: FileKind
    let title: String
    let entries: [AgentFileEntry]
}

struct HarnessSnapshot: Identifiable, Hashable {
    let harness: Harness
    let groups: [FileGroup]

    var id: Harness { harness }

    var fileCount: Int {
        groups.reduce(0) { $0 + $1.entries.filter(\.exists).count }
    }
}
