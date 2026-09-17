import AppKit
import SwiftUI

struct EditorPaneView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if appModel.selectedTemplate != nil && appModel.selectedEntry == nil {
                CodeEditor(text: $appModel.editorText)
            } else if let entry = appModel.selectedEntry {
                if entry.isDirectory {
                    directoryPlaceholder(entry)
                } else {
                    CodeEditor(text: $appModel.editorText)
                }
            } else {
                ContentUnavailableView("No File Selected", systemImage: "text.alignleft")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                    if appModel.isDirty {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                            .help("Unsaved changes")
                    }
                    if appModel.selectedTemplate != nil && appModel.selectedEntry == nil {
                        Text("Template preview")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            if let template = appModel.selectedTemplate, appModel.selectedEntry == nil {
                Button("Apply Template") {
                    appModel.requestApplyTemplate(id: template.id)
                }
                .buttonStyle(.borderedProminent)
            } else if let entry = appModel.selectedEntry, !entry.exists, !entry.isDirectory {
                Button("Create & Save") {
                    appModel.saveCurrentFile()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Save") {
                    appModel.saveCurrentFile()
                }
                .disabled(!appModel.canSave)
            }
            if let entry = appModel.selectedEntry {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([entry.url])
                } label: {
                    Image(systemName: "folder")
                }
                .help("Reveal in Finder")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var title: String {
        if let template = appModel.selectedTemplate, appModel.selectedEntry == nil {
            return template.name
        }
        guard let entry = appModel.selectedEntry else { return "Editor" }
        if entry.url.lastPathComponent == "SKILL.md" {
            return entry.url.deletingLastPathComponent().lastPathComponent
        }
        return entry.name
    }

    private var subtitle: String {
        if let template = appModel.selectedTemplate, appModel.selectedEntry == nil {
            return template.description
        }
        return appModel.selectedEntry?.relativeDisplayPath ?? "Select a file or template"
    }

    private func directoryPlaceholder(_ entry: AgentFileEntry) -> some View {
        ContentUnavailableView {
            Label("Directory", systemImage: "folder")
        } description: {
            Text(entry.relativeDisplayPath)
            Text("Use New Skill or apply a skill template to add files here.")
        }
    }
}

struct CodeEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.string = text
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textColor = NSColor.textColor
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selected = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selected
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditor
        weak var textView: NSTextView?

        init(_ parent: CodeEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
