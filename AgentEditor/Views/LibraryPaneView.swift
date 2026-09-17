import SwiftUI

private enum LibraryPaneMode: String, CaseIterable, Identifiable {
    case templates
    case backups

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .templates: "Templates"
        case .backups: "Backups"
        }
    }
}

struct LibraryPaneView: View {
    @AppStorage("AgentEditor.libraryPaneMode") private var mode: LibraryPaneMode = .templates

    var body: some View {
        VStack(spacing: 0) {
            Picker("Library", selection: $mode) {
                ForEach(LibraryPaneMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(10)

            Divider()

            Group {
                switch mode {
                case .templates:
                    TemplatesPaneView()
                case .backups:
                    BackupPaneView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
