import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        List(selection: Binding(
            get: { appModel.selectedHarness },
            set: { if let value = $0 { appModel.changeHarness(value) } }
        )) {
            Section("Harness") {
                ForEach(Harness.allCases) { harness in
                    Label {
                        HStack {
                            Text(harness.displayName)
                            Spacer()
                            if let snap = appModel.snapshots.first(where: { $0.harness == harness }) {
                                Text("\(snap.fileCount)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: harness.systemImage)
                    }
                    .tag(harness)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("AgentEditor")
        .frame(minWidth: 180)
    }
}
