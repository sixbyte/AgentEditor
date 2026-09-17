import Foundation

enum TemplateLibraryError: LocalizedError {
    case rootNotFound
    case templateNotFound(String)
    case incompatibleHarness(String)
    case unsupportedInstructionScope(String)
    case missingProject
    case applyFailed(String)
    case destinationExists(String)

    var errorDescription: String? {
        switch self {
        case .rootNotFound:
            "Template library not found."
        case .templateNotFound(let id):
            "Template not found: \(id)"
        case .incompatibleHarness(let name):
            "This template is not marked compatible with \(name)."
        case .unsupportedInstructionScope(let message):
            message
        case .missingProject:
            "Select a project folder before applying project-scoped templates."
        case .applyFailed(let message):
            "Failed to apply template: \(message)"
        case .destinationExists(let path):
            "Destination already exists: \(path)"
        }
    }
}

enum TemplateLibraryService {
    /// Resolves Templates/ from the app bundle, then nearby repo checkout, then env override.
    static func resolveRoot(
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) -> URL? {
        if let override = UserDefaults.standard.string(forKey: "AgentEditor.templatesRoot"),
           !override.isEmpty {
            let url = URL(fileURLWithPath: override, isDirectory: true)
            if fileManager.fileExists(atPath: url.path) {
                return url
            }
        }

        if let bundled = bundle.resourceURL?.appendingPathComponent("Templates", isDirectory: true),
           fileManager.fileExists(atPath: bundled.path) {
            return bundled
        }

        // Dev fallback: walk up from the executable / current directory looking for Templates/
        let candidates = [
            URL(fileURLWithPath: fileManager.currentDirectoryPath),
            Bundle.main.bundleURL.deletingLastPathComponent(),
            Bundle.main.bundleURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent(),
        ]

        for start in candidates {
            var cursor = start
            for _ in 0..<6 {
                let templates = cursor.appendingPathComponent("Templates", isDirectory: true)
                if fileManager.fileExists(atPath: templates.appendingPathComponent("catalog.json").path)
                    || fileManager.fileExists(atPath: templates.appendingPathComponent("instructions").path) {
                    return templates
                }
                let parent = cursor.deletingLastPathComponent()
                if parent.path == cursor.path { break }
                cursor = parent
            }
        }
        return nil
    }

    static func loadTemplates(from root: URL) -> [AgentTemplate] {
        let categories = ["instructions", "skills", "rules"]
        var results: [AgentTemplate] = []

        for category in categories {
            let categoryURL = root.appendingPathComponent(category, isDirectory: true)
            guard let children = try? FileManager.default.contentsOfDirectory(
                at: categoryURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for dir in children {
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir),
                      isDir.boolValue else { continue }
                let manifestURL = dir.appendingPathComponent("template.json")
                guard let data = try? Data(contentsOf: manifestURL),
                      let manifest = try? JSONDecoder().decode(TemplateManifest.self, from: data) else {
                    continue
                }
                results.append(AgentTemplate(manifest: manifest, rootURL: dir))
            }
        }

        return results.sorted {
            if $0.category != $1.category {
                return $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending
            }
            if $0.kind != $1.kind {
                return kindOrder($0.kind) < kindOrder($1.kind)
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func kindOrder(_ kind: FileKind) -> Int {
        switch kind {
        case .instructions: 0
        case .rules: 1
        case .skills: 2
        case .other: 3
        }
    }

    static func destinationRoot(
        for template: AgentTemplate,
        harness: Harness,
        scope: FileScope,
        projectRoot: URL?,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> URL {
        let base: URL
        switch scope {
        case .user:
            base = home
        case .project:
            guard let projectRoot else { throw TemplateLibraryError.missingProject }
            base = projectRoot
        }

        switch template.kind {
        case .instructions:
            return base
        case .skills:
            return base.appendingPathComponent(skillsRelativePath(harness: harness, scope: scope), isDirectory: true)
        case .rules:
            return base.appendingPathComponent(rulesRelativePath(harness: harness, scope: scope), isDirectory: true)
        case .other:
            return base
        }
    }

    static func skillsRelativePath(harness: Harness, scope: FileScope) -> String {
        switch (harness, scope) {
        case (.cursor, _): return ".cursor/skills"
        case (.claude, _): return ".claude/skills"
        case (.codex, _): return ".agents/skills"
        case (.openCode, .user): return ".config/opencode/skills"
        case (.openCode, .project): return ".opencode/skills"
        }
    }

    static func rulesRelativePath(harness: Harness, scope: FileScope) -> String {
        switch (harness, scope) {
        case (.cursor, .user), (.cursor, .project): return ".cursor/rules"
        case (.claude, .user), (.claude, .project): return ".claude/rules"
        case (.codex, .user): return ".codex"
        case (.codex, .project): return "."
        case (.openCode, .user): return ".config/opencode"
        case (.openCode, .project): return ".opencode"
        }
    }

    static func destinationURLs(
        for template: AgentTemplate,
        harness: Harness,
        scope: FileScope,
        projectRoot: URL?,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> [URL] {
        guard template.manifest.supports(harness: harness) else {
            throw TemplateLibraryError.incompatibleHarness(harness.displayName)
        }
        switch template.kind {
        case .instructions:
            return [try instructionDestinationURL(
                for: template,
                harness: harness,
                scope: scope,
                projectRoot: projectRoot,
                home: home
            )]
        case .skills:
            let root = try destinationRoot(
                for: template,
                harness: harness,
                scope: scope,
                projectRoot: projectRoot,
                home: home
            )
            let children = try FileManager.default.contentsOfDirectory(
                at: template.rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            guard let skillDirectory = children.first(where: {
                FileManager.default.fileExists(atPath: $0.appendingPathComponent("SKILL.md").path)
            }) else {
                throw TemplateLibraryError.applyFailed("No skill folder with SKILL.md found.")
            }
            return [root.appendingPathComponent(skillDirectory.lastPathComponent, isDirectory: true)]
        case .rules:
            let root = try destinationRoot(
                for: template,
                harness: harness,
                scope: scope,
                projectRoot: projectRoot,
                home: home
            )
            let files = try FileManager.default.contentsOfDirectory(
                at: template.rootURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ).filter {
                $0.lastPathComponent != "template.json"
                    && ["md", "mdc", "markdown"].contains($0.pathExtension.lowercased())
            }
            guard !files.isEmpty else {
                throw TemplateLibraryError.applyFailed("No rule files found in template.")
            }
            return files.map { root.appendingPathComponent($0.lastPathComponent) }
        case .other:
            throw TemplateLibraryError.applyFailed("Unsupported template kind.")
        }
    }

    static func conflictingDestinations(
        for template: AgentTemplate,
        harness: Harness,
        scope: FileScope,
        projectRoot: URL?
    ) throws -> [URL] {
        try destinationURLs(
            for: template,
            harness: harness,
            scope: scope,
            projectRoot: projectRoot
        ).filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Copies template payload into the harness destination.
    /// - Returns: URLs that were written.
    @discardableResult
    static func apply(
        _ template: AgentTemplate,
        harness: Harness,
        scope: FileScope,
        projectRoot: URL?,
        overwrite: Bool,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> [URL] {
        guard template.manifest.supports(harness: harness) else {
            throw TemplateLibraryError.incompatibleHarness(harness.displayName)
        }

        switch template.kind {
        case .instructions:
            let destination = try instructionDestinationURL(
                for: template,
                harness: harness,
                scope: scope,
                projectRoot: projectRoot,
                home: home
            )
            return try applyInstruction(template, to: destination, overwrite: overwrite)
        case .skills:
            let destinationRoot = try destinationRoot(
                for: template,
                harness: harness,
                scope: scope,
                projectRoot: projectRoot,
                home: home
            )
            return try applySkill(template, to: destinationRoot, overwrite: overwrite)
        case .rules:
            let destinationRoot = try destinationRoot(
                for: template,
                harness: harness,
                scope: scope,
                projectRoot: projectRoot,
                home: home
            )
            return try applyRules(template, to: destinationRoot, overwrite: overwrite)
        case .other:
            throw TemplateLibraryError.applyFailed("Unsupported template kind.")
        }
    }

    private static func applyInstruction(
        _ template: AgentTemplate,
        to destination: URL,
        overwrite: Bool
    ) throws -> [URL] {
        let fileName = template.manifest.targetFileName ?? "AGENTS.md"
        let source = template.rootURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: source.path) else {
            // Fall back to first markdown file in the template folder.
            guard let md = firstMarkdown(in: template.rootURL) else {
                throw TemplateLibraryError.applyFailed("No instruction file found in template.")
            }
            try copyFile(md, to: destination, overwrite: overwrite)
            return [destination]
        }
        try copyFile(source, to: destination, overwrite: overwrite)
        return [destination]
    }

    private static func instructionDestinationURL(
        for template: AgentTemplate,
        harness: Harness,
        scope: FileScope,
        projectRoot: URL?,
        home: URL
    ) throws -> URL {
        switch scope {
        case .project:
            guard let projectRoot else { throw TemplateLibraryError.missingProject }
            let defaultFileName = harness == .claude ? "CLAUDE.md" : "AGENTS.md"
            let fileName = template.manifest.targetFileName ?? defaultFileName
            return projectRoot.appendingPathComponent(fileName)
        case .user:
            switch harness {
            case .cursor:
                throw TemplateLibraryError.unsupportedInstructionScope(
                    "Cursor loads AGENTS.md from a project root. Switch to Project scope, or use a Cursor rule for global instructions."
                )
            case .claude:
                return home.appendingPathComponent(".claude/CLAUDE.md")
            case .codex:
                return home.appendingPathComponent(".codex/AGENTS.md")
            case .openCode:
                return home.appendingPathComponent(".config/opencode/AGENTS.md")
            }
        }
    }

    private static func applySkill(
        _ template: AgentTemplate,
        to destinationRoot: URL,
        overwrite: Bool
    ) throws -> [URL] {
        // Skill payload is a child folder containing SKILL.md (exclude template.json).
        let children = try FileManager.default.contentsOfDirectory(
            at: template.rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        let skillDirs = children.filter { url in
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
                return false
            }
            return FileManager.default.fileExists(atPath: url.appendingPathComponent("SKILL.md").path)
        }

        guard let skillDir = skillDirs.first else {
            throw TemplateLibraryError.applyFailed("No skill folder with SKILL.md found.")
        }

        let dest = destinationRoot.appendingPathComponent(skillDir.lastPathComponent, isDirectory: true)
        try copyDirectory(skillDir, to: dest, overwrite: overwrite)
        return [dest.appendingPathComponent("SKILL.md")]
    }

    private static func applyRules(
        _ template: AgentTemplate,
        to destinationRoot: URL,
        overwrite: Bool
    ) throws -> [URL] {
        let files = try FileManager.default.contentsOfDirectory(
            at: template.rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            let name = url.lastPathComponent
            guard name != "template.json" else { return false }
            let ext = url.pathExtension.lowercased()
            return ext == "md" || ext == "mdc" || ext == "markdown"
        }

        guard !files.isEmpty else {
            throw TemplateLibraryError.applyFailed("No rule files found in template.")
        }

        try FileManager.default.createDirectory(at: destinationRoot, withIntermediateDirectories: true)
        var written: [URL] = []
        for file in files {
            let dest = destinationRoot.appendingPathComponent(file.lastPathComponent)
            try copyFile(file, to: dest, overwrite: overwrite)
            written.append(dest)
        }
        return written
    }

    private static func firstMarkdown(in directory: URL) -> URL? {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return files.first {
            $0.lastPathComponent != "template.json"
                && ["md", "mdc", "markdown"].contains($0.pathExtension.lowercased())
        }
    }

    private static func copyFile(_ source: URL, to destination: URL, overwrite: Bool) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: destination.path) {
            if overwrite {
                try fm.removeItem(at: destination)
            } else {
                throw TemplateLibraryError.destinationExists(destination.path)
            }
        }
        do {
            try fm.copyItem(at: source, to: destination)
        } catch {
            throw TemplateLibraryError.applyFailed(error.localizedDescription)
        }
    }

    private static func copyDirectory(_ source: URL, to destination: URL, overwrite: Bool) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: destination.path) {
            if overwrite {
                try fm.removeItem(at: destination)
            } else {
                throw TemplateLibraryError.destinationExists(destination.path)
            }
        }
        do {
            try fm.copyItem(at: source, to: destination)
        } catch {
            throw TemplateLibraryError.applyFailed(error.localizedDescription)
        }
    }
}
