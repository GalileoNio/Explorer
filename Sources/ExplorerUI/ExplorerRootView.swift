import ExplorerCore
import SwiftUI
import UniformTypeIdentifiers

public struct ExplorerRootView: View {
    @ObservedObject private var controller: ExplorerController
    @State private var isGrantingAccess = false

    public init(controller: ExplorerController) {
        self.controller = controller
    }

    public var body: some View {
        NavigationSplitView {
            PlacesSidebar(controller: controller)
        } detail: {
            BrowserPane(controller: controller)
        }
        .alert(
            "Explorer",
            isPresented: Binding(
                get: { controller.errorMessage != nil },
                set: { if !$0 { controller.clearError() } }
            )
        ) {
            if controller.accessRequest != nil {
                Button("Grant Access...") {
                    controller.clearError()
                    isGrantingAccess = true
                }

                #if os(macOS)
                Button("Full Disk Access...") {
                    controller.clearError()
                    PlatformFileServices.openFullDiskAccessSettings()
                }
                #endif

                Button("Cancel", role: .cancel) {
                    controller.clearError()
                }
            } else {
                Button("OK") {
                    controller.clearError()
                }
            }
        } message: {
            if let accessRequest = controller.accessRequest {
                Text(
                    "\(controller.errorMessage ?? "")\n\nChoose \"\(accessRequest.title)\" or one of its parent folders to grant Explorer access."
                )
            } else {
                Text(controller.errorMessage ?? "")
            }
        }
        .fileImporter(
            isPresented: $isGrantingAccess,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    return
                }

                controller.authorizeAccess(to: url)
            case .failure(let error):
                if !isUserCancelled(error) {
                    controller.present(error)
                }
            }
        }
    }

    private func isUserCancelled(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError
    }
}
