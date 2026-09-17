import SwiftUI
import UniformTypeIdentifiers

struct TemplatesPaneView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selectedCategory: String?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Template type", selection: $appModel.selectedTemplateType) {
                ForEach(TemplateLibraryType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            TextField("Filter templates", text: $appModel.templateFilter)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            if appModel.templates.isEmpty {
                ContentUnavailableView {
                    Label("No Templates", systemImage: "square.stack.3d.up.slash")
                } description: {
                    Text("Point Settings at the repo Templates/ folder, or rebuild so templates are bundled.")
                } actions: {
                    Button("Choose Templates Folder…") {
                        appModel.pickTemplatesRoot()
                    }
                }
            } else if let selectedCategory {
                categoryContents(selectedCategory)
            } else {
                categoryList
            }

            Divider()
            selectionBar
        }
        .background(.background)
        .onChange(of: appModel.selectedTemplateType) { _, _ in
            selectedCategory = nil
            appModel.selectedTemplateID = nil
        }
        .onChange(of: appModel.selectedHarness) { _, _ in
            selectedCategory = nil
        }
        .onChange(of: appModel.templateFilter) { _, _ in
            if let selectedCategory,
               !appModel.templatesByCategory.contains(where: { $0.category == selectedCategory }) {
                self.selectedCategory = nil
            }
        }
    }

    @ViewBuilder
    private var categoryList: some View {
        if appModel.templatesByCategory.isEmpty {
            ContentUnavailableView.search(text: appModel.templateFilter)
        } else {
            List(appModel.templatesByCategory, id: \.category) { section in
                Button {
                    selectedCategory = section.category
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "folder")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.category)
                                .foregroundStyle(.primary)
                            Text("\(section.items.count) \(section.items.count == 1 ? "template" : "templates")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.sidebar)
        }
    }

    private func categoryContents(_ category: String) -> some View {
        let templates = appModel.templatesByCategory
            .first(where: { $0.category == category })?.items ?? []

        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    selectedCategory = nil
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .help("Back to categories")

                Text(category)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("\(templates.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            List(selection: Binding(
                get: { appModel.selectedTemplateID },
                set: { if let id = $0 { appModel.selectTemplate(id: id) } }
            )) {
                ForEach(templates) { template in
                    TemplateRowView(template: template)
                        .tag(template.id)
                        .draggable(template.id)
                }
            }
            .listStyle(.sidebar)
        }
    }

    private var selectionBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button("Select All") {
                    for template in templatesShownInCurrentLevel {
                        if appModel.canApplyTemplate(template) {
                            appModel.setTemplateSelected(template.id, isSelected: true)
                        }
                    }
                }
                .buttonStyle(.link)
                .disabled(!templatesShownInCurrentLevel.contains(where: appModel.canApplyTemplate))

                Button("Clear") {
                    appModel.clearTemplateSelection()
                }
                .buttonStyle(.link)
                .disabled(appModel.selectedTemplateCount == 0)

                Spacer()

                Button("Apply \(appModel.selectedTemplateCount) Selected") {
                    appModel.requestApplySelectedTemplates()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(appModel.selectedTemplateCount == 0)
            }

            Text("Check multiple templates, or drag one onto the environment list.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
    }

    private var templatesShownInCurrentLevel: [AgentTemplate] {
        guard let selectedCategory else { return appModel.filteredTemplates }
        return appModel.templatesByCategory
            .first(where: { $0.category == selectedCategory })?.items ?? []
    }
}

private struct TemplateRowView: View {
    @EnvironmentObject private var appModel: AppModel
    let template: AgentTemplate

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Toggle("", isOn: Binding(
                get: { appModel.selectedTemplateIDs.contains(template.id) },
                set: { appModel.setTemplateSelected(template.id, isSelected: $0) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            .disabled(!appModel.canApplyTemplate(template))
            .help("Include in batch apply")

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(template.name)
                        .font(.body)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button {
                        appModel.requestApplyTemplate(id: template.id)
                    } label: {
                        Image(systemName: "plus.app")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!appModel.canApplyTemplate(template))
                    .help("Apply to current harness / scope")
                }
                Text(template.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Label(template.kind.displayName, systemImage: template.kind.systemImage)
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    if let availability = appModel.templateAvailabilityLabel(template) {
                        Text(availability)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.orange)
                    }
                    if !template.tags.isEmpty {
                        Text(template.tags.joined(separator: " · "))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .help(
            appModel.canApplyTemplate(template)
                ? "Drag onto the environment file list to apply"
                : "Switch to Project scope to apply this AGENTS.md template in Cursor"
        )
    }
}
