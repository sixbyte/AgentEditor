import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedHarness: Harness = .cursor
    @Published var selectedScope: FileScope = .user
    @Published var projectRoot: URL? {
        didSet { persistProjectRoot() }
    }
    @Published var snapshots: [HarnessSnapshot] = []
    @Published var selectedEntryID: AgentFileEntry.ID?
    @Published var editorText: String = ""
    @Published var loadedText: String = ""
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var showMissingFiles: Bool = true
    @Published var pendingNavigation: PendingNavigation?
    @Published var templates: [AgentTemplate] = []
    @Published var templatesRoot: URL?
    @Published var selectedTemplateID: AgentTemplate.ID?
    @Published var selectedTemplateIDs: Set<AgentTemplate.ID> = []
    @Published var selectedTemplateType: TemplateLibraryType = .agent
    @Published var templateFilter: String = ""
    @Published var pendingTemplateApply: PendingTemplateApply?
    @Published var isDropTargeted: Bool = false
    @Published var backups: [AgentBackup] = []
    @Published var backupName: String = ""
    @Published var pendingBackupRestore: AgentBackup?
    @Published var pendingFileDeletion: PendingFileDeletion?

    struct PendingTemplateApply: Identifiable, Equatable {
        let id = UUID()
        let templateIDs: [String]
        let destinationHint: String
    }

    struct PendingFileDeletion: Identifiable, Equatable {
        let entry: AgentFileEntry
        let targetURL: URL

        var id: String { entry.id }

        var displayName: String {
            targetURL.lastPathComponent
        }

        var deletesSkillFolder: Bool {
            entry.kind == .skills && targetURL != entry.url
        }
    }

    enum PendingNavigation: Identifiable, Equatable {
        case entry(AgentFileEntry.ID)
        case harness(Harness)
        case scope(FileScope)

        var id: String {
            switch self {
            case .entry(let value): "entry-\(value)"
            case .harness(let value): "harness-\(value.rawValue)"
            case .scope(let value): "scope-\(value.rawValue)"
            }
        }
    }

    private let projectRootKey = "AgentEditor.projectRoot"
    private let templatesRootKey = "AgentEditor.templatesRoot"

    var canSave: Bool {
        guard selectedEntry != nil else { return false }
        return isDirty
    }

    var canDeleteSelectedEntry: Bool {
        guard let selectedEntry else { return false }
        return selectedEntry.exists && !selectedEntry.isDirectory
    }

    var isDirty: Bool {
        editorText != loadedText
    }

    var selectedEntry: AgentFileEntry? {
        guard let selectedEntryID else { return nil }
        return allEntries.first { $0.id == selectedEntryID }
    }

    var selectedTemplate: AgentTemplate? {
        guard let selectedTemplateID else { return nil }
        return templates.first { $0.id == selectedTemplateID }
    }

    var filteredTemplates: [AgentTemplate] {
        let query = templateFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        return templates.filter { template in
            guard template.manifest.supports(harness: selectedHarness) else { return false }
            guard template.libraryType == selectedTemplateType else { return false }
            guard !query.isEmpty else { return true }
            let haystack = [
                template.name,
                template.description,
                template.category,
                template.kind.displayName,
                template.tags.joined(separator: " "),
            ].joined(separator: " ").lowercased()
            return haystack.contains(query.lowercased())
        }
    }

    var templatesByCategory: [(category: String, items: [AgentTemplate])] {
        let grouped = Dictionary(grouping: filteredTemplates, by: \.category)
        return grouped.keys.sorted { lhs, rhs in
            let leftRank = templateCategoryRank(lhs)
            let rightRank = templateCategoryRank(rhs)
            if leftRank != rightRank { return leftRank < rightRank }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }.map { category in
            let items = grouped[category, default: []].sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return (category, items)
        }
    }

    var selectedTemplateCount: Int {
        selectedTemplateIDs.intersection(Set(
            filteredTemplates.filter(canApplyTemplate).map(\.id)
        )).count
    }

    func canApplyTemplate(_ template: AgentTemplate) -> Bool {
        !(template.kind == .instructions && selectedHarness == .cursor && selectedScope == .user)
    }

    func templateAvailabilityLabel(_ template: AgentTemplate) -> String? {
        canApplyTemplate(template) ? nil : "Project only"
    }

    var currentGroups: [FileGroup] {
        snapshots.first(where: { $0.harness == selectedHarness })?.groups ?? []
    }

    var visibleGroups: [FileGroup] {
        currentGroups.compactMap { group in
            let entries = group.entries.filter { showMissingFiles || $0.exists }
            guard !entries.isEmpty else { return nil }
            return FileGroup(id: group.id, kind: group.kind, title: group.title, entries: entries)
        }
    }

    private var allEntries: [AgentFileEntry] {
        snapshots.flatMap { $0.groups.flatMap(\.entries) }
    }

    init() {
        if let path = UserDefaults.standard.string(forKey: projectRootKey) {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                projectRoot = url
            }
        }
        refreshTemplates()
        refresh()
    }

    func refreshTemplates() {
        templatesRoot = TemplateLibraryService.resolveRoot()
        if let templatesRoot {
            templates = TemplateLibraryService.loadTemplates(from: templatesRoot)
            selectedTemplateIDs.formIntersection(templates.map(\.id))
            statusMessage = "Loaded \(templates.count) templates from \(displayPath(templatesRoot))"
        } else {
            templates = []
            statusMessage = "Template library not found. Set a Templates folder in Settings."
        }
    }

    func pickTemplatesRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Select the Templates folder from the AgentEditor repository (or a clone)."
        if panel.runModal() == .OK, let url = panel.url {
            UserDefaults.standard.set(url.path, forKey: templatesRootKey)
            refreshTemplates()
        }
    }

    func clearTemplatesRootOverride() {
        UserDefaults.standard.removeObject(forKey: templatesRootKey)
        refreshTemplates()
    }

    func refresh() {
        let previousID = selectedEntryID
        snapshots = Harness.allCases.map { harness in
            let groups = FileDiscoveryService.discover(
                harness: harness,
                scope: selectedScope,
                projectRoot: projectRoot
            )
            return HarnessSnapshot(harness: harness, groups: groups)
        }

        if let previousID, allEntries.contains(where: { $0.id == previousID }) {
            forceSelectEntry(id: previousID)
        } else if let first = visibleGroups.first?.entries.first(where: { !$0.isDirectory && $0.exists })
            ?? visibleGroups.first?.entries.first(where: { !$0.isDirectory }) {
            forceSelectEntry(id: first.id)
        } else {
            selectedEntryID = nil
            editorText = ""
            loadedText = ""
        }
        refreshBackups()
    }

    func refreshBackups() {
        backups = BackupService.loadBackups(
            harness: selectedHarness,
            scope: selectedScope,
            projectRoot: projectRoot
        )
    }

    func saveNamedBackup() {
        do {
            let backup = try BackupService.createBackup(
                name: backupName,
                harness: selectedHarness,
                scope: selectedScope,
                projectRoot: projectRoot
            )
            backupName = ""
            refreshBackups()
            statusMessage = "Saved backup “\(backup.name)” for \(selectedHarness.displayName) / \(selectedScope.displayName)"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestRestoreBackup(_ backup: AgentBackup) {
        pendingBackupRestore = backup
    }

    func cancelBackupRestore() {
        pendingBackupRestore = nil
    }

    func restorePendingBackup() {
        guard let backup = pendingBackupRestore else { return }
        do {
            _ = try BackupService.createBackup(
                name: "Before restoring \(backup.name)",
                harness: selectedHarness,
                scope: selectedScope,
                projectRoot: projectRoot
            )
            try BackupService.restore(
                backup,
                harness: selectedHarness,
                scope: selectedScope,
                projectRoot: projectRoot
            )
            pendingBackupRestore = nil
            refresh()
            statusMessage = "Restored backup “\(backup.name)”"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestDeleteSelectedEntry() {
        guard let selectedEntry else { return }
        requestDeleteEntry(selectedEntry)
    }

    func requestDeleteEntry(_ entry: AgentFileEntry) {
        guard entry.exists, !entry.isDirectory else { return }
        pendingFileDeletion = PendingFileDeletion(
            entry: entry,
            targetURL: FileIOService.deletionTarget(for: entry)
        )
    }

    func cancelFileDeletion() {
        pendingFileDeletion = nil
    }

    func confirmFileDeletion() {
        guard let pending = pendingFileDeletion else { return }
        pendingFileDeletion = nil
        let targetURL = pending.targetURL
        let displayName = pending.displayName

        NSWorkspace.shared.recycle([targetURL]) { [weak self] _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    self.errorMessage = "Failed to move \(displayName) to Trash: \(error.localizedDescription)"
                    return
                }
                self.refresh()
                self.statusMessage = "Moved \(displayName) to Trash"
                self.errorMessage = nil
            }
        }
    }

    func selectEntry(id: AgentFileEntry.ID) {
        guard id != selectedEntryID else { return }
        if isDirty {
            pendingNavigation = .entry(id)
            return
        }
        forceSelectEntry(id: id)
    }

    func selectTemplate(id: AgentTemplate.ID) {
        selectedTemplateID = id
        guard let template = templates.first(where: { $0.id == id }) else { return }
        if let previewURL = previewURL(for: template),
           let text = try? FileIOService.readText(at: previewURL) {
            if isDirty {
                statusMessage = "Template preview available. Save or discard editor changes to open it."
                return
            }
            selectedEntryID = nil
            editorText = text
            loadedText = text
            statusMessage = "Preview: \(template.name)"
        }
    }

    func setTemplateSelected(_ id: AgentTemplate.ID, isSelected: Bool) {
        if isSelected {
            selectedTemplateIDs.insert(id)
        } else {
            selectedTemplateIDs.remove(id)
        }
    }

    func selectAllVisibleTemplates() {
        selectedTemplateIDs.formUnion(filteredTemplates.filter(canApplyTemplate).map(\.id))
    }

    func clearTemplateSelection() {
        selectedTemplateIDs.removeAll()
    }

    func confirmDiscardPending() {
        guard let pendingNavigation else { return }
        loadedText = editorText
        let pending = pendingNavigation
        self.pendingNavigation = nil
        applyNavigation(pending)
    }

    func cancelPendingNavigation() {
        pendingNavigation = nil
    }

    func saveAndContinuePending() {
        saveCurrentFile()
        guard !isDirty, let pendingNavigation else { return }
        let pending = pendingNavigation
        self.pendingNavigation = nil
        applyNavigation(pending)
    }

    private func applyNavigation(_ pending: PendingNavigation) {
        switch pending {
        case .entry(let id):
            forceSelectEntry(id: id)
        case .harness(let harness):
            selectedHarness = harness
            selectFirstVisibleFile()
        case .scope(let scope):
            selectedScope = scope
            refresh()
        }
    }

    private func forceSelectEntry(id: AgentFileEntry.ID) {
        selectedEntryID = id
        selectedTemplateID = nil
        errorMessage = nil
        guard let entry = allEntries.first(where: { $0.id == id }) else {
            editorText = ""
            loadedText = ""
            return
        }

        if entry.isDirectory {
            editorText = ""
            loadedText = ""
            statusMessage = "This is a directory. Create a file or select one inside it."
            return
        }

        if !entry.exists {
            editorText = FileIOService.defaultTemplate(for: entry)
            loadedText = editorText
            statusMessage = "File does not exist yet. Save to create it."
            return
        }

        do {
            let text = try FileIOService.readText(at: entry.url)
            editorText = text
            loadedText = text
            statusMessage = entry.relativeDisplayPath
        } catch {
            editorText = ""
            loadedText = ""
            errorMessage = error.localizedDescription
        }
    }

    func saveCurrentFile() {
        guard let entry = selectedEntry else { return }
        if entry.isDirectory {
            errorMessage = FileIOError.isDirectory.errorDescription
            return
        }
        do {
            try FileIOService.writeText(editorText, to: entry.url)
            loadedText = editorText
            statusMessage = "Saved: \(entry.relativeDisplayPath)"
            errorMessage = nil
            refreshKeepingSelection()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createSelectedPlaceholder() {
        guard let entry = selectedEntry, !entry.exists, !entry.isDirectory else { return }
        do {
            let template = editorText.isEmpty ? FileIOService.defaultTemplate(for: entry) : editorText
            try FileIOService.createFile(at: entry.url, template: template)
            editorText = template
            loadedText = template
            statusMessage = "Created: \(entry.relativeDisplayPath)"
            errorMessage = nil
            refreshKeepingSelection()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createSkill(named rawName: String) {
        let name = rawName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
        guard !name.isEmpty else { return }

        let base: URL?
        switch selectedScope {
        case .user:
            base = FileManager.default.homeDirectoryForCurrentUser
        case .project:
            base = projectRoot
        }
        guard let base else {
            errorMessage = "No project selected."
            return
        }

        let skillsRoot = TemplateLibraryService.skillsRelativePath(
            harness: selectedHarness,
            scope: selectedScope
        )

        let skillURL = base
            .appendingPathComponent(skillsRoot)
            .appendingPathComponent(name)
            .appendingPathComponent("SKILL.md")

        let entry = AgentFileEntry(
            id: "new|\(skillURL.path)",
            url: skillURL,
            harness: selectedHarness,
            scope: selectedScope,
            kind: .skills,
            categoryLabel: "New Skill",
            exists: false,
            isDirectory: false
        )

        do {
            let template = FileIOService.defaultTemplate(for: entry)
            try FileIOService.createFile(at: skillURL, template: template)
            refresh()
            if let created = allEntries.first(where: { $0.url.path == skillURL.path }) {
                loadedText = editorText
                forceSelectEntry(id: created.id)
            }
            statusMessage = "Created skill: \(name)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestApplyTemplate(id: String) {
        requestApplyTemplates(ids: [id])
    }

    func requestApplySelectedTemplates() {
        let visibleIDs = Set(filteredTemplates.filter(canApplyTemplate).map(\.id))
        requestApplyTemplates(ids: templates.map(\.id).filter {
            selectedTemplateIDs.contains($0) && visibleIDs.contains($0)
        })
    }

    private func requestApplyTemplates(ids: [String]) {
        guard !ids.isEmpty else {
            errorMessage = "Select at least one template to apply."
            return
        }

        do {
            let selectedTemplates = try ids.map { id in
                guard let template = templates.first(where: { $0.id == id }) else {
                    throw TemplateLibraryError.templateNotFound(id)
                }
                guard template.manifest.supports(harness: selectedHarness) else {
                    throw TemplateLibraryError.incompatibleHarness(selectedHarness.displayName)
                }
                return template
            }

            let destinations = try selectedTemplates.flatMap { template in
                try TemplateLibraryService.destinationURLs(
                    for: template,
                    harness: selectedHarness,
                    scope: selectedScope,
                    projectRoot: projectRoot
                )
            }
            let counts = Dictionary(grouping: destinations, by: \.standardizedFileURL.path)
            let duplicateDestinations = counts.values.compactMap { $0.count > 1 ? $0[0] : nil }
            if !duplicateDestinations.isEmpty {
                errorMessage = "Some selected templates target the same destination: \(conflictSummary(duplicateDestinations)). Choose only one template for each destination."
                return
            }
            let existingDestinations = destinations.filter {
                FileManager.default.fileExists(atPath: $0.path)
            }
            let conflicts = Array(Set(existingDestinations))

            if !conflicts.isEmpty {
                pendingTemplateApply = PendingTemplateApply(
                    templateIDs: ids,
                    destinationHint: conflictSummary(conflicts)
                )
            } else {
                applyTemplates(ids: ids, overwrite: false)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyTemplate(id: String, overwrite: Bool) {
        applyTemplates(ids: [id], overwrite: overwrite)
    }

    func applyTemplates(ids: [String], overwrite: Bool) {
        guard !ids.isEmpty else { return }
        do {
            var written: [URL] = []
            var appliedNames: [String] = []
            for id in ids {
                guard let template = templates.first(where: { $0.id == id }) else {
                    throw TemplateLibraryError.templateNotFound(id)
                }
                written.append(contentsOf: try TemplateLibraryService.apply(
                    template,
                    harness: selectedHarness,
                    scope: selectedScope,
                    projectRoot: projectRoot,
                    overwrite: overwrite
                ))
                appliedNames.append(template.name)
            }
            pendingTemplateApply = nil
            selectedTemplateIDs.subtract(ids)
            refresh()
            if let first = written.first,
               let entry = allEntries.first(where: { $0.url.path == first.path }) {
                forceSelectEntry(id: entry.id)
            }
            let label = appliedNames.count == 1 ? appliedNames[0] : "\(appliedNames.count) templates"
            statusMessage = "Applied \(label) → \(selectedHarness.displayName) / \(selectedScope.displayName)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelTemplateApply() {
        pendingTemplateApply = nil
    }

    private func previewURL(for template: AgentTemplate) -> URL? {
        switch template.kind {
        case .instructions:
            let name = template.manifest.targetFileName ?? "AGENTS.md"
            let url = template.rootURL.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) { return url }
            return firstPreviewFile(in: template.rootURL)
        case .skills:
            let children = (try? FileManager.default.contentsOfDirectory(
                at: template.rootURL,
                includingPropertiesForKeys: nil
            )) ?? []
            return children
                .map { $0.appendingPathComponent("SKILL.md") }
                .first { FileManager.default.fileExists(atPath: $0.path) }
        case .rules, .other:
            return firstPreviewFile(in: template.rootURL)
        }
    }

    private func firstPreviewFile(in directory: URL) -> URL? {
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

    func pickProject() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Choose a project folder whose agent config files you want to manage."
        if panel.runModal() == .OK, let url = panel.url {
            projectRoot = url
            if selectedScope == .project {
                refresh()
            }
        }
    }

    func clearProject() {
        projectRoot = nil
        if selectedScope == .project {
            refresh()
        }
    }

    func changeScope(_ scope: FileScope) {
        guard scope != selectedScope else { return }
        if isDirty {
            pendingNavigation = .scope(scope)
            return
        }
        selectedScope = scope
        refresh()
    }

    func changeHarness(_ harness: Harness) {
        guard harness != selectedHarness else { return }
        if isDirty {
            pendingNavigation = .harness(harness)
            return
        }
        selectedHarness = harness
        selectFirstVisibleFile()
    }

    private func selectFirstVisibleFile() {
        refreshBackups()
        if let first = visibleGroups.first?.entries.first(where: { !$0.isDirectory }) {
            forceSelectEntry(id: first.id)
        } else {
            selectedEntryID = nil
            editorText = ""
            loadedText = ""
        }
    }

    private func refreshKeepingSelection() {
        let id = selectedEntryID
        let text = editorText
        let loaded = loadedText
        snapshots = Harness.allCases.map { harness in
            let groups = FileDiscoveryService.discover(
                harness: harness,
                scope: selectedScope,
                projectRoot: projectRoot
            )
            return HarnessSnapshot(harness: harness, groups: groups)
        }
        selectedEntryID = id
        editorText = text
        loadedText = loaded
    }

    private func persistProjectRoot() {
        if let projectRoot {
            UserDefaults.standard.set(projectRoot.path, forKey: projectRootKey)
        } else {
            UserDefaults.standard.removeObject(forKey: projectRootKey)
        }
    }

    private func displayPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func conflictSummary(_ urls: [URL]) -> String {
        let paths = urls.map(displayPath).sorted()
        if paths.count == 1 { return paths[0] }
        return paths.prefix(3).joined(separator: ", ") + (paths.count > 3 ? " and \(paths.count - 3) more" : "")
    }

    private func templateCategoryRank(_ category: String) -> Int {
        let order: [String]
        switch selectedTemplateType {
        case .agent:
            order = ["Research", "Coding", "Finance", "Security"]
        case .skill:
            order = ["Web Design", "Coding", "Security", "Finance", "Legal"]
        }
        return order.firstIndex(of: category) ?? order.count
    }
}
