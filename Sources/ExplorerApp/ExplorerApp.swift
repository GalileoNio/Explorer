import ExplorerCore
import ExplorerUI
import SwiftUI

@main
struct ExplorerApp: App {
    @StateObject private var controller = ExplorerController()

    var body: some Scene {
        WindowGroup {
            ExplorerRootView(controller: controller)
                #if os(macOS)
                .frame(minWidth: 900, minHeight: 620)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1080, height: 720)
        #endif
        .commands {
            ExplorerCommands(controller: controller)
        }
    }
}

struct ExplorerCommands: Commands {
    @ObservedObject var controller: ExplorerController

    var body: some Commands {
        CommandMenu("File") {
            Button("New Folder") {
                controller.createFolder()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("Reload") {
                controller.loadCurrentDirectory()
            }
            .keyboardShortcut("r", modifiers: .command)

            Divider()

            Button("Back") {
                controller.goBack()
            }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(!controller.state.canGoBack)

            Button("Forward") {
                controller.goForward()
            }
            .keyboardShortcut("]", modifiers: .command)
            .disabled(!controller.state.canGoForward)

            Button("Up") {
                controller.navigateUp()
            }
            .keyboardShortcut(.upArrow, modifiers: .command)
        }

        CommandMenu("View") {
            Picker("View Mode", selection: Binding(
                get: { controller.state.viewMode },
                set: { controller.setViewMode($0) }
            )) {
                Text("Grid").tag(FileViewMode.grid)
                Text("List").tag(FileViewMode.list)
            }

            Toggle("Show Hidden Files", isOn: Binding(
                get: { controller.state.showHiddenFiles },
                set: { controller.setShowHiddenFiles($0) }
            ))
            .keyboardShortcut(".", modifiers: [.command, .shift])
        }
    }
}

