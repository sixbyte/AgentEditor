import Foundation

enum BackupServiceError: LocalizedError {
    case missingProject
    case emptyName
    case invalidBackup
    case incompatibleDestination
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingProject:
            "Select a project folder before saving or restoring a project backup."
        case .emptyName:
            "Enter a name for this backup."
        case .invalidBackup:
            "The selected backup is incomplete or invalid."
        case .incompatibleDestination:
            "This backup belongs to a different harness, scope, or project."
        case .operationFailed(let message):
            "Backup operation failed: \(message)"
        }
    }
}

enum BackupService {
    private static let manifestName = "backup.json"
    private static let payloadDirectoryName = "payload"

    static func defaultRoot(fileManager: FileManager = .default) -> URL {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return applicationSupport
            .appendingPathComponent("AgentEditor", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
    }

    static func sourceRoot(
        scope: FileScope,
        projectRoot: URL?,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> URL {
        switch scope {
        case .user:
            return home.standardizedFileURL
        case .project:
            guard let projectRoot else { throw BackupServiceError.missingProject }
            return projectRoot.standardizedFileURL
        }
    }

    static func createBackup(
        name rawName: String,
        harness: Harness,
        scope: FileScope,
        projectRoot: URL?,
        backupRoot: URL = defaultRoot(),
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) throws -> AgentBackup {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw BackupServiceError.emptyName }

        let source = try sourceRoot(scope: scope, projectRoot: projectRoot, home: home)
        let id = UUID()
        let root = backupRoot
            .appendingPathComponent(harness.rawValue, isDirectory: true)
            .appendingPathComponent(scope.rawValue, isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        let payload = root.appendingPathComponent(payloadDirectoryName, isDirectory: true)

        do {
            try fileManager.createDirectory(at: payload, withIntermediateDirectories: true)
            let items = try managedTargets(harness: harness, scope: scope).map { target in
                let sourceURL = try safeURL(relativePath: target.relativePath, under: source)
                var isDirectory: ObjCBool = false
                let exists = fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory)
                let item = AgentBackupItem(
                    relativePath: target.relativePath,
                    kind: target.kind,
                    wasPresent: exists,
                    isDirectory: exists ? isDirectory.boolValue : target.isDirectory
                )
                if exists {
                    let destination = try safeURL(relativePath: target.relativePath, under: payload)
                    try fileManager.createDirectory(
                        at: destination.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try fileManager.copyItem(at: sourceURL, to: destination)
                }
                return item
            }

            let manifest = AgentBackupManifest(
                id: id,
                name: name,
                harness: harness,
                scope: scope,
                sourceRootPath: source.path,
                createdAt: Date(),
                items: items
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(manifest)
            try data.write(to: root.appendingPathComponent(manifestName), options: .atomic)
            return AgentBackup(manifest: manifest, rootURL: root)
        } catch {
            try? fileManager.removeItem(at: root)
            if let error = error as? BackupServiceError { throw error }
            throw BackupServiceError.operationFailed(error.localizedDescription)
        }
    }

    static func loadBackups(
        harness: Harness,
        scope: FileScope,
        projectRoot: URL?,
        backupRoot: URL = defaultRoot(),
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) -> [AgentBackup] {
        guard let expectedSource = try? sourceRoot(scope: scope, projectRoot: projectRoot, home: home) else {
            return []
        }
        let container = backupRoot
            .appendingPathComponent(harness.rawValue, isDirectory: true)
            .appendingPathComponent(scope.rawValue, isDirectory: true)
        let directories = (try? fileManager.contentsOfDirectory(
            at: container,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return directories.compactMap { directory in
            let manifestURL = directory.appendingPathComponent(manifestName)
            guard let data = try? Data(contentsOf: manifestURL),
                  let manifest = try? decoder.decode(AgentBackupManifest.self, from: data),
                  manifest.harness == harness,
                  manifest.scope == scope,
                  URL(fileURLWithPath: manifest.sourceRootPath).standardizedFileURL.path == expectedSource.path else {
                return nil
            }
            return AgentBackup(manifest: manifest, rootURL: directory)
        }.sorted { $0.createdAt > $1.createdAt }
    }

    static func restore(
        _ backup: AgentBackup,
        harness: Harness,
        scope: FileScope,
        projectRoot: URL?,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) throws {
        let destinationRoot = try sourceRoot(scope: scope, projectRoot: projectRoot, home: home)
        guard backup.manifest.harness == harness,
              backup.manifest.scope == scope,
              URL(fileURLWithPath: backup.manifest.sourceRootPath).standardizedFileURL.path == destinationRoot.path else {
            throw BackupServiceError.incompatibleDestination
        }

        let payload = backup.rootURL.appendingPathComponent(payloadDirectoryName, isDirectory: true)
        guard fileManager.fileExists(atPath: backup.rootURL.appendingPathComponent(manifestName).path) else {
            throw BackupServiceError.invalidBackup
        }

        do {
            for item in backup.manifest.items {
                let destination = try safeURL(relativePath: item.relativePath, under: destinationRoot)
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                guard item.wasPresent else { continue }

                let source = try safeURL(relativePath: item.relativePath, under: payload)
                guard fileManager.fileExists(atPath: source.path) else {
                    throw BackupServiceError.invalidBackup
                }
                try fileManager.createDirectory(
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try fileManager.copyItem(at: source, to: destination)
            }
        } catch {
            if let error = error as? BackupServiceError { throw error }
            throw BackupServiceError.operationFailed(error.localizedDescription)
        }
    }

    private static func managedTargets(harness: Harness, scope: FileScope) -> [PathCatalog.Target] {
        let targets = scope == .user
            ? PathCatalog.userTargets(for: harness)
            : PathCatalog.projectTargets(for: harness)
        var seen = Set<String>()
        return targets.filter { target in
            guard target.kind == .instructions || target.kind == .skills else { return false }
            return seen.insert(target.relativePath).inserted
        }
    }

    private static func safeURL(relativePath: String, under root: URL) throws -> URL {
        guard !relativePath.hasPrefix("/"),
              !relativePath.split(separator: "/").contains("..") else {
            throw BackupServiceError.invalidBackup
        }
        let standardizedRoot = root.standardizedFileURL
        let result = standardizedRoot.appendingPathComponent(relativePath).standardizedFileURL
        guard result.path.hasPrefix(standardizedRoot.path + "/") else {
            throw BackupServiceError.invalidBackup
        }
        return result
    }
}
