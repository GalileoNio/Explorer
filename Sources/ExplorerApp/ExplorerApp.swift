import ExplorerCore
import ExplorerUI
import SwiftUI

@main
struct ExplorerApp: App {
    var body: some Scene {
        WindowGroup {
            ExplorerWindow()
                #if os(macOS)
                .frame(minWidth: 900, minHeight: 620)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1080, height: 720)
        #endif
        .commands {
            ExplorerCommands()
        }

        #if os(macOS)
        Settings {
            ExplorerSettingsView()
        }
        #endif
    }
}

struct ExplorerWindow: View {
    @StateObject private var controller = ExplorerController()

    var body: some View {
        ExplorerRootView(controller: controller)
            .focusedSceneValue(\.explorerController, controller)
    }
}

struct ExplorerCommands: Commands {
    @FocusedValue(\.explorerController) private var controller

    var body: some Commands {
        CommandMenu("File") {
            Button("New Folder") {
                controller?.createFolder()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(controller == nil)

            Button("Reload") {
                controller?.loadCurrentDirectory()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(controller == nil)

            Divider()

            Button("Back") {
                controller?.goBack()
            }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(controller?.state.canGoBack != true)

            Button("Forward") {
                controller?.goForward()
            }
            .keyboardShortcut("]", modifiers: .command)
            .disabled(controller?.state.canGoForward != true)

            Button("Up") {
                controller?.navigateUp()
            }
            .keyboardShortcut(.upArrow, modifiers: .command)
            .disabled(controller == nil)
        }

        CommandMenu("View") {
            Picker("View Mode", selection: Binding(
                get: { controller?.state.viewMode ?? .grid },
                set: { controller?.setViewMode($0) }
            )) {
                Text("Grid").tag(FileViewMode.grid)
                Text("List").tag(FileViewMode.list)
            }
            .disabled(controller == nil)

            Toggle("Show Hidden Files", isOn: Binding(
                get: { controller?.state.showHiddenFiles ?? false },
                set: { controller?.setShowHiddenFiles($0) }
            ))
            .keyboardShortcut(".", modifiers: [.command, .shift])
            .disabled(controller == nil)
        }
    }
}

private struct ExplorerControllerFocusedValueKey: FocusedValueKey {
    typealias Value = ExplorerController
}

extension FocusedValues {
    var explorerController: ExplorerController? {
        get { self[ExplorerControllerFocusedValueKey.self] }
        set { self[ExplorerControllerFocusedValueKey.self] = newValue }
    }
}

#if os(macOS)
struct ExplorerSettingsView: View {
    @AppStorage(ExplorerPreferenceKeys.pathBarInTitleBar) private var pathBarInTitleBar = false

    var body: some View {
        Form {
            Toggle("Address Bar in Title Bar", isOn: $pathBarInTitleBar)
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 360)
    }
}
#endif
