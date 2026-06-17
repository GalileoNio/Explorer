import ExplorerCore
import SwiftUI
import UniformTypeIdentifiers

struct PlacesSidebar: View {
    @ObservedObject var controller: ExplorerController
    @State private var isChoosingFolder = false
    @State private var detailsTarget: FileItem?

    private let places = DefaultPlaces.primaryPlaces()

    var body: some View {
        List {
            Section("Places") {
                ForEach(places) { place in
                    placeButton(
                        title: place.title,
                        symbol: place.systemImageName,
                        url: place.url
                    )
                }
            }

            if !controller.authorizedRoots.isEmpty {
                Section("Authorized") {
                    ForEach(controller.authorizedRoots) { root in
                        placeButton(
                            title: root.title,
                            symbol: "folder.badge.person.crop",
                            url: root.url,
                            isAuthorized: true,
                            onRemove: {
                                controller.removeAuthorizedRoot(root)
                            }
                        )
                    }
                }
            }

            Section("Access") {
                Button {
                    isChoosingFolder = true
                } label: {
                    Label("Add Folder...", systemImage: "folder.badge.plus")
                }
            }
        }
        .navigationTitle("Explorer")
        .fileImporter(
            isPresented: $isChoosingFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    return
                }

                controller.addAuthorizedRoot(url)
                controller.navigate(to: url)
            case .failure(let error):
                controller.present(error)
            }
        }
        .sheet(item: $detailsTarget) { item in
            FileInfoSheet(item: item, controller: controller)
        }
    }

    private func placeButton(
        title: String,
        symbol: String,
        url: URL,
        isAuthorized: Bool = false,
        onRemove: (() -> Void)? = nil
    ) -> some View {
        Button {
            controller.navigate(to: url)
        } label: {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .listRowBackground(
            controller.state.currentURL == url ? Color.accentColor.opacity(0.14) : Color.clear
        )
        .contextMenu {
            PlaceActionMenu(
                title: title,
                url: url,
                isAuthorized: isAuthorized,
                controller: controller,
                onDetails: { detailsTarget = $0 },
                onRemove: onRemove
            )
        }
    }
}
