import ExplorerCore
import SwiftUI

public struct ExplorerRootView: View {
    @ObservedObject private var controller: ExplorerController

    public init(controller: ExplorerController) {
        self.controller = controller
    }

    public var body: some View {
        NavigationSplitView {
            PlacesSidebar(controller: controller)
        } detail: {
            BrowserPane(controller: controller)
        }
        .searchable(
            text: Binding(
                get: { controller.state.searchQuery },
                set: { controller.setSearchQuery($0) }
            ),
            placement: .toolbar,
            prompt: "Search current folder"
        )
        .searchToolbarBehavior(.automatic)
        .onAppear {
            controller.start()
        }
        .alert(
            "Explorer",
            isPresented: Binding(
                get: { controller.errorMessage != nil },
                set: { if !$0 { controller.clearError() } }
            )
        ) {
            Button("OK") {
                controller.clearError()
            }
        } message: {
            Text(controller.errorMessage ?? "")
        }
    }
}

