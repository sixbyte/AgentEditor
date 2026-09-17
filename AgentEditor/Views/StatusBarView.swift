import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        HStack(spacing: 12) {
            if appModel.isDirty {
                Label("Unsaved", systemImage: "pencil.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
            Text(appModel.statusMessage ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            if let root = appModel.templatesRoot {
                Text("Templates: \(root.lastPathComponent)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
            }
            Text(appModel.selectedHarness.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("·")
                .foregroundStyle(.tertiary)
            Text(appModel.selectedScope.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
