import Foundation
import XCTest
@testable import AgentEditor

final class TemplateLibraryServiceTests: XCTestCase {
    func testRepositoryTemplateLibraryLoadsExpectedContent() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let templatesRoot = repositoryRoot.appendingPathComponent("Templates", isDirectory: true)

        let templates = TemplateLibraryService.loadTemplates(from: templatesRoot)
        let ids = Set(templates.map(\.id))

        XCTAssertGreaterThanOrEqual(templates.count, 23)
        XCTAssertTrue(ids.contains("agents-focused"))
        XCTAssertTrue(ids.contains("claude-basic"))
        XCTAssertTrue(ids.contains("skill-instruction-audit"))
        XCTAssertEqual(Set(templates.filter { $0.libraryType == .agent }.map(\.category)), [
            "Research",
            "Coding",
            "Finance",
            "Security",
        ])
        XCTAssertEqual(Set(templates.filter { $0.libraryType == .skill }.map(\.category)), [
            "Web Design",
            "Coding",
            "Security",
            "Finance",
            "Legal",
        ])
    }

    func testInstructionDestinationUsesProjectRoot() throws {
        let projectRoot = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: projectRoot) }

        let template = AgentTemplate(
            manifest: TemplateManifest(
                id: "focused",
                name: "Focused AGENTS.md",
                description: "Focused instructions",
                kind: .instructions,
                targetFileName: "AGENTS.md",
                compatibleHarnesses: ["codex"]
            ),
            rootURL: projectRoot
        )

        let destinations = try TemplateLibraryService.destinationURLs(
            for: template,
            harness: .codex,
            scope: .project,
            projectRoot: projectRoot
        )

        XCTAssertEqual(destinations, [projectRoot.appendingPathComponent("AGENTS.md")])
    }

    func testUserInstructionDestinationsMatchHarnessDiscoveryPaths() throws {
        let home = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }

        let agentsTemplate = AgentTemplate(
            manifest: TemplateManifest(
                id: "focused",
                name: "Focused AGENTS.md",
                description: "Focused instructions",
                kind: .instructions,
                targetFileName: "AGENTS.md",
                compatibleHarnesses: ["codex", "openCode"]
            ),
            rootURL: home
        )
        let claudeTemplate = AgentTemplate(
            manifest: TemplateManifest(
                id: "claude",
                name: "CLAUDE.md",
                description: "Claude instructions",
                kind: .instructions,
                targetFileName: "CLAUDE.md",
                compatibleHarnesses: ["claude"]
            ),
            rootURL: home
        )

        XCTAssertEqual(
            try TemplateLibraryService.destinationURLs(
                for: agentsTemplate,
                harness: .codex,
                scope: .user,
                projectRoot: nil,
                home: home
            ),
            [home.appendingPathComponent(".codex/AGENTS.md")]
        )
        XCTAssertEqual(
            try TemplateLibraryService.destinationURLs(
                for: agentsTemplate,
                harness: .openCode,
                scope: .user,
                projectRoot: nil,
                home: home
            ),
            [home.appendingPathComponent(".config/opencode/AGENTS.md")]
        )
        XCTAssertEqual(
            try TemplateLibraryService.destinationURLs(
                for: claudeTemplate,
                harness: .claude,
                scope: .user,
                projectRoot: nil,
                home: home
            ),
            [home.appendingPathComponent(".claude/CLAUDE.md")]
        )
    }

    func testCursorUserInstructionRequiresProjectScope() throws {
        let home = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }

        let template = AgentTemplate(
            manifest: TemplateManifest(
                id: "focused",
                name: "Focused AGENTS.md",
                description: "Focused instructions",
                kind: .instructions,
                targetFileName: "AGENTS.md",
                compatibleHarnesses: ["cursor"]
            ),
            rootURL: home
        )

        XCTAssertThrowsError(
            try TemplateLibraryService.destinationURLs(
                for: template,
                harness: .cursor,
                scope: .user,
                projectRoot: nil,
                home: home
            )
        ) { error in
            guard case TemplateLibraryError.unsupportedInstructionScope = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testApplyingUserInstructionWritesToDiscoveredCodexPath() throws {
        let workingRoot = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workingRoot) }

        let templateRoot = workingRoot.appendingPathComponent("template", isDirectory: true)
        try FileManager.default.createDirectory(at: templateRoot, withIntermediateDirectories: true)
        try "# Applied instructions".write(
            to: templateRoot.appendingPathComponent("AGENTS.md"),
            atomically: true,
            encoding: .utf8
        )
        let template = AgentTemplate(
            manifest: TemplateManifest(
                id: "focused",
                name: "Focused AGENTS.md",
                description: "Focused instructions",
                kind: .instructions,
                targetFileName: "AGENTS.md",
                compatibleHarnesses: ["codex"]
            ),
            rootURL: templateRoot
        )
        let home = workingRoot.appendingPathComponent("home", isDirectory: true)

        let written = try TemplateLibraryService.apply(
            template,
            harness: .codex,
            scope: .user,
            projectRoot: nil,
            overwrite: false,
            home: home
        )

        let expected = home.appendingPathComponent(".codex/AGENTS.md")
        XCTAssertEqual(written, [expected])
        XCTAssertEqual(try String(contentsOf: expected, encoding: .utf8), "# Applied instructions")
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent("AGENTS.md").path))

        let discovered = FileDiscoveryService.discover(
            harness: .codex,
            scope: .user,
            projectRoot: nil,
            home: home
        ).flatMap(\.entries)
        XCTAssertTrue(discovered.contains(where: { $0.url == expected && $0.exists }))
    }

    func testApplyingSkillCreatesStandardCodexLayout() throws {
        let workingRoot = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workingRoot) }

        let templateRoot = workingRoot.appendingPathComponent("template", isDirectory: true)
        let skillRoot = templateRoot.appendingPathComponent("instruction-audit", isDirectory: true)
        try FileManager.default.createDirectory(at: skillRoot, withIntermediateDirectories: true)
        let skillSource = skillRoot.appendingPathComponent("SKILL.md")
        try "---\nname: instruction-audit\ndescription: Audit instruction files.\n---\n".write(
            to: skillSource,
            atomically: true,
            encoding: .utf8
        )

        let template = AgentTemplate(
            manifest: TemplateManifest(
                id: "instruction-audit",
                name: "Instruction Audit",
                description: "Audit instruction files",
                kind: .skills,
                compatibleHarnesses: ["codex"]
            ),
            rootURL: templateRoot
        )
        let projectRoot = workingRoot.appendingPathComponent("project", isDirectory: true)

        let written = try TemplateLibraryService.apply(
            template,
            harness: .codex,
            scope: .project,
            projectRoot: projectRoot,
            overwrite: false
        )

        let expected = projectRoot
            .appendingPathComponent(".agents/skills/instruction-audit/SKILL.md")
        XCTAssertEqual(written, [expected])
        XCTAssertTrue(FileManager.default.fileExists(atPath: expected.path))
    }

    func testExistingInstructionIsReportedAsConflict() throws {
        let projectRoot = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: projectRoot) }
        let existing = projectRoot.appendingPathComponent("AGENTS.md")
        try "Existing".write(to: existing, atomically: true, encoding: .utf8)

        let template = AgentTemplate(
            manifest: TemplateManifest(
                id: "focused",
                name: "Focused AGENTS.md",
                description: "Focused instructions",
                kind: .instructions,
                targetFileName: "AGENTS.md",
                compatibleHarnesses: ["codex"]
            ),
            rootURL: projectRoot
        )

        let conflicts = try TemplateLibraryService.conflictingDestinations(
            for: template,
            harness: .codex,
            scope: .project,
            projectRoot: projectRoot
        )

        XCTAssertEqual(conflicts, [existing])
    }

    func testInstructionDeletionTargetsOnlyTheSelectedFile() {
        let url = URL(fileURLWithPath: "/tmp/project/AGENTS.md")
        let entry = AgentFileEntry(
            id: "instruction",
            url: url,
            harness: .codex,
            scope: .project,
            kind: .instructions,
            categoryLabel: "AGENTS.md",
            exists: true,
            isDirectory: false
        )

        XCTAssertEqual(FileIOService.deletionTarget(for: entry), url)
    }

    func testSkillDeletionTargetsTheCompleteSkillFolder() {
        let skillFile = URL(fileURLWithPath: "/tmp/project/.agents/skills/reviewer/SKILL.md")
        let entry = AgentFileEntry(
            id: "skill",
            url: skillFile,
            harness: .codex,
            scope: .project,
            kind: .skills,
            categoryLabel: "Project Skills",
            exists: true,
            isDirectory: false
        )

        XCTAssertEqual(
            FileIOService.deletionTarget(for: entry),
            skillFile.deletingLastPathComponent()
        )
    }

    private func makeTemporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentEditorTests-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
