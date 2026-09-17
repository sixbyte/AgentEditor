import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let agentTemplateID = UTType(exportedAs: "com.agenteditor.template-id")
}

enum TemplateLibraryType: String, CaseIterable, Identifiable {
    case agent
    case skill

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .agent: "AGENT"
        case .skill: "SKILL"
        }
    }
}

struct TemplateManifest: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let description: String
    let category: String
    let kind: FileKind
    let targetFileName: String?
    let compatibleHarnesses: [String]
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, description, category, kind, targetFileName, compatibleHarnesses, tags
    }

    init(
        id: String,
        name: String,
        description: String,
        category: String = "General",
        kind: FileKind,
        targetFileName: String? = nil,
        compatibleHarnesses: [String] = [],
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.kind = kind
        self.targetFileName = targetFileName
        self.compatibleHarnesses = compatibleHarnesses
        self.tags = tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "General"
        let kindRaw = try container.decode(String.self, forKey: .kind)
        kind = FileKind(rawValue: kindRaw) ?? .other
        targetFileName = try container.decodeIfPresent(String.self, forKey: .targetFileName)
        compatibleHarnesses = try container.decodeIfPresent([String].self, forKey: .compatibleHarnesses) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    func supports(harness: Harness) -> Bool {
        guard !compatibleHarnesses.isEmpty else { return true }
        return compatibleHarnesses.contains(harness.rawValue)
    }
}

struct AgentTemplate: Identifiable, Hashable {
    let manifest: TemplateManifest
    let rootURL: URL

    var id: String { manifest.id }
    var name: String { manifest.name }
    var description: String { manifest.description }
    var category: String { manifest.category }
    var kind: FileKind { manifest.kind }
    var tags: [String] { manifest.tags }

    var libraryType: TemplateLibraryType {
        kind == .skills ? .skill : .agent
    }
}
