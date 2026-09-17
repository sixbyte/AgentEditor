import Foundation

enum Harness: String, CaseIterable, Identifiable, Hashable, Codable {
    case cursor
    case claude
    case codex
    case openCode

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cursor: "Cursor"
        case .claude: "Claude Code"
        case .codex: "Codex"
        case .openCode: "OpenCode"
        }
    }

    var systemImage: String {
        switch self {
        case .cursor: "cursorarrow.rays"
        case .claude: "brain.head.profile"
        case .codex: "terminal"
        case .openCode: "chevron.left.forwardslash.chevron.right"
        }
    }
}

enum FileKind: String, CaseIterable, Identifiable, Hashable, Codable {
    case instructions
    case rules
    case skills
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .instructions: "Instructions"
        case .rules: "Rules"
        case .skills: "Skills"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .instructions: "doc.text"
        case .rules: "list.bullet.rectangle"
        case .skills: "wrench.and.screwdriver"
        case .other: "doc"
        }
    }
}

enum FileScope: String, CaseIterable, Identifiable, Hashable, Codable {
    case user
    case project

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .user: "User (Global)"
        case .project: "Project"
        }
    }
}
