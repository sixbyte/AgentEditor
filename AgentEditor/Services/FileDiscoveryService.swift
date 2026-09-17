import Foundation

enum FileDiscoveryService {
    static func discover(
        harness: Harness,
        scope: FileScope,
        projectRoot: URL?,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [FileGroup] {
        let base: URL?
        let targets: [PathCatalog.Target]

        switch scope {
        case .user:
            base = home
            targets = PathCatalog.userTargets(for: harness)
        case .project:
            base = projectRoot
            targets = PathCatalog.projectTargets(for: harness)
        }

        guard let base else { return [] }

        var grouped: [FileKind: [(label: String, entries: [AgentFileEntry])]] = [:]

        for target in targets {
            let rootURL = base.appendingPathComponent(target.relativePath)
            var entries: [AgentFileEntry] = []

            if target.isDirectory {
                if target.expandFiles {
                    let files = collectFiles(under: rootURL, patterns: target.filePatterns)
                    if files.isEmpty {
                        // Show the directory itself as a placeholder when missing or empty.
                        entries.append(
                            makeEntry(
                                url: rootURL,
                                harness: harness,
                                scope: scope,
                                kind: target.kind,
                                categoryLabel: target.categoryLabel,
                                exists: FileManager.default.fileExists(atPath: rootURL.path),
                                isDirectory: true
                            )
                        )
                    } else {
                        entries.append(contentsOf: files.map {
                            makeEntry(
                                url: $0,
                                harness: harness,
                                scope: scope,
                                kind: target.kind,
                                categoryLabel: target.categoryLabel,
                                exists: true,
                                isDirectory: false
                            )
                        })
                    }
                }
            } else {
                let exists = FileManager.default.fileExists(atPath: rootURL.path)
                entries.append(
                    makeEntry(
                        url: rootURL,
                        harness: harness,
                        scope: scope,
                        kind: target.kind,
                        categoryLabel: target.categoryLabel,
                        exists: exists,
                        isDirectory: false
                    )
                )
            }

            if !entries.isEmpty {
                grouped[target.kind, default: []].append((target.categoryLabel, entries))
            }
        }

        let order: [FileKind] = [.instructions, .rules, .skills, .other]
        return order.compactMap { kind in
            guard let sections = grouped[kind], !sections.isEmpty else { return nil }
            let flat = sections.flatMap(\.entries)
            // Deduplicate by path while preserving order.
            var seen = Set<String>()
            let unique = flat.filter { seen.insert($0.url.path).inserted }
            return FileGroup(
                id: "\(harness.rawValue)-\(scope.rawValue)-\(kind.rawValue)",
                kind: kind,
                title: kind.displayName,
                entries: unique
            )
        }
    }

    private static func makeEntry(
        url: URL,
        harness: Harness,
        scope: FileScope,
        kind: FileKind,
        categoryLabel: String,
        exists: Bool,
        isDirectory: Bool
    ) -> AgentFileEntry {
        AgentFileEntry(
            id: "\(harness.rawValue)|\(scope.rawValue)|\(url.path)",
            url: url,
            harness: harness,
            scope: scope,
            kind: kind,
            categoryLabel: categoryLabel,
            exists: exists,
            isDirectory: isDirectory
        )
    }

    private static func collectFiles(under directory: URL, patterns: [String]) -> [URL] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: directory.path, isDirectory: &isDir), isDir.boolValue else {
            return []
        }

        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var results: [URL] = []
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            if matches(fileURL: fileURL, patterns: patterns) {
                results.append(fileURL)
            }
        }
        return results.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
    }

    private static func matches(fileURL: URL, patterns: [String]) -> Bool {
        guard !patterns.isEmpty else { return true }
        let name = fileURL.lastPathComponent
        return patterns.contains { pattern in
            if pattern.hasPrefix("*.") {
                let ext = String(pattern.dropFirst(2))
                return fileURL.pathExtension.caseInsensitiveCompare(ext) == .orderedSame
            }
            return name.caseInsensitiveCompare(pattern) == .orderedSame
        }
    }
}
