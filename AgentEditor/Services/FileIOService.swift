import Foundation

enum FileIOError: LocalizedError {
    case isDirectory
    case readFailed(String)
    case writeFailed(String)
    case createFailed(String)

    var errorDescription: String? {
        switch self {
        case .isDirectory:
            "Directories cannot be edited directly. Select a file inside or create one."
        case .readFailed(let message):
            "Failed to read file: \(message)"
        case .writeFailed(let message):
            "Failed to save file: \(message)"
        case .createFailed(let message):
            "Failed to create file: \(message)"
        }
    }
}

enum FileIOService {
    static func deletionTarget(for entry: AgentFileEntry) -> URL {
        if entry.kind == .skills && entry.url.lastPathComponent == "SKILL.md" {
            return entry.url.deletingLastPathComponent()
        }
        return entry.url
    }

    static func readText(at url: URL) throws -> String {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            throw FileIOError.isDirectory
        }
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw FileIOError.readFailed(error.localizedDescription)
        }
    }

    static func writeText(_ text: String, to url: URL) throws {
        let parent = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw FileIOError.writeFailed(error.localizedDescription)
        }
    }

    static func createFile(at url: URL, template: String) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            return
        }
        do {
            try writeText(template, to: url)
        } catch let error as FileIOError {
            throw error
        } catch {
            throw FileIOError.createFailed(error.localizedDescription)
        }
    }

    static func defaultTemplate(for entry: AgentFileEntry) -> String {
        let name = entry.url.lastPathComponent
        if name == "SKILL.md" {
            let skillName = entry.url.deletingLastPathComponent().lastPathComponent
            return """
            ---
            name: \(skillName)
            description: TODO — when to use this skill
            ---

            # \(skillName)

            Describe the workflow here.
            """
        }
        if name.hasSuffix(".mdc") {
            let title = entry.url.deletingPathExtension().lastPathComponent
            return """
            ---
            description: \(title)
            alwaysApply: false
            ---

            # \(title)

            """
        }
        if name == "AGENTS.md" || name == "AGENTS.override.md" || name == "CLAUDE.md" {
            return """
            # \(name)

            Add agent instructions here.
            """
        }
        return "# \(name)\n\n"
    }
}
