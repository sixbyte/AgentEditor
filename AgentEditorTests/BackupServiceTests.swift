import Foundation
import XCTest
@testable import AgentEditor

final class BackupServiceTests: XCTestCase {
    func testBackupRestoresExactHarnessInstructionAndSkillSet() throws {
        let workingRoot = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workingRoot) }

        let projectRoot = workingRoot.appendingPathComponent("project", isDirectory: true)
        let backupRoot = workingRoot.appendingPathComponent("backups", isDirectory: true)
        let agentsFile = projectRoot.appendingPathComponent("AGENTS.md")
        let skillFile = projectRoot.appendingPathComponent(".agents/skills/reviewer/SKILL.md")
        try write("Original instructions", to: agentsFile)
        try write("Original skill", to: skillFile)

        let backup = try BackupService.createBackup(
            name: "Working set",
            harness: .codex,
            scope: .project,
            projectRoot: projectRoot,
            backupRoot: backupRoot
        )

        try write("Changed instructions", to: agentsFile)
        try write("Changed skill", to: skillFile)
        let extraSkill = projectRoot.appendingPathComponent(".agents/skills/temporary/SKILL.md")
        try write("Temporary skill", to: extraSkill)

        try BackupService.restore(
            backup,
            harness: .codex,
            scope: .project,
            projectRoot: projectRoot
        )

        XCTAssertEqual(try String(contentsOf: agentsFile, encoding: .utf8), "Original instructions")
        XCTAssertEqual(try String(contentsOf: skillFile, encoding: .utf8), "Original skill")
        XCTAssertFalse(FileManager.default.fileExists(atPath: extraSkill.path))
    }

    func testBackupsAreFilteredByHarnessScopeAndProject() throws {
        let workingRoot = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workingRoot) }

        let firstProject = workingRoot.appendingPathComponent("first", isDirectory: true)
        let secondProject = workingRoot.appendingPathComponent("second", isDirectory: true)
        let backupRoot = workingRoot.appendingPathComponent("backups", isDirectory: true)
        try FileManager.default.createDirectory(at: firstProject, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondProject, withIntermediateDirectories: true)

        _ = try BackupService.createBackup(
            name: "First project set",
            harness: .cursor,
            scope: .project,
            projectRoot: firstProject,
            backupRoot: backupRoot
        )

        let matching = BackupService.loadBackups(
            harness: .cursor,
            scope: .project,
            projectRoot: firstProject,
            backupRoot: backupRoot
        )
        let otherProject = BackupService.loadBackups(
            harness: .cursor,
            scope: .project,
            projectRoot: secondProject,
            backupRoot: backupRoot
        )
        let otherHarness = BackupService.loadBackups(
            harness: .codex,
            scope: .project,
            projectRoot: firstProject,
            backupRoot: backupRoot
        )

        XCTAssertEqual(matching.map(\.name), ["First project set"])
        XCTAssertTrue(otherProject.isEmpty)
        XCTAssertTrue(otherHarness.isEmpty)
    }

    private func write(_ contents: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    private func makeTemporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentEditorBackupTests-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
