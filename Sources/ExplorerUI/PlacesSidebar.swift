import ExplorerCore
import SwiftUI
import UniformTypeIdentifiers

struct PlacesSidebar: View {
    @ObservedObject var controller: ExplorerController
    @State private var isChoosingFolder = false
    @State private var detailsTarget: FileItem?
    @State private var sidebarSelection: URL?

    private let places = DefaultPlaces.primaryPlaces()

    var body: some View {
        List(selection: $sidebarSelection) {
            Section("Places") {
                ForEach(places) { place in
                    placeRow(
                        title: place.title,
                        symbol: place.systemImageName,
                        url: place.url
                    )
                }
            }

            if !controller.authorizedRoots.isEmpty {
                Section("Authorized") {
                    ForEach(controller.authorizedRoots) { root in
                        placeRow(
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
        .listStyle(.sidebar)
        .navigationTitle("Explorer")
        .onAppear {
            syncSidebarSelection()
        }
        .onChange(of: controller.state.currentURL) {
            syncSidebarSelection()
        }
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

    private func placeRow(
        title: String,
        symbol: String,
        url: URL,
        isAuthorized: Bool = false,
        onRemove: (() -> Void)? = nil
    ) -> some View {
        let standardizedURL = url.standardizedFileURL

        return Label(title, systemImage: symbol)
            .foregroundStyle(.primary, .secondary)
            .tag(standardizedURL)
            .contentShape(Rectangle())
            .onTapGesture {
                sidebarSelection = standardizedURL
                controller.navigate(to: standardizedURL)
            }
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

    private func syncSidebarSelection() {
        sidebarSelection = selectedSidebarURL(for: controller.state.currentURL)
    }

    private func selectedSidebarURL(for url: URL) -> URL? {
        let candidates = (places.map(\.url) + controller.authorizedRoots.map(\.url))
            .map(\.standardizedFileURL)
        let currentPath = url.standardizedFileURL.path

        return candidates
            .filter { candidate in
                currentPath == candidate.path
                    || candidate.path == "/"
                    || currentPath.hasPrefix(candidate.path + "/")
            }
            .max { left, right in
                left.path.count < right.path.count
            }
    }
}
