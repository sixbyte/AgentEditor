import SwiftUI

@main
struct AgentEditorApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
                .frame(minWidth: 1100, minHeight: 680)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Project…") {
                    appModel.pickProject()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Reload") {
                    appModel.refreshTemplates()
                    appModel.refresh()
                }
                .keyboardShortcut("r", modifiers: [.command])
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    appModel.saveCurrentFile()
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(!appModel.canSave)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appModel)
        }
    }
}
