import ExplorerCore
import SwiftUI
import UniformTypeIdentifiers

struct PlacesSidebar: View {
    @ObservedObject var controller: ExplorerController
    @State private var isChoosingFolder = false
    @State private var detailsTarget: FileItem?
    @State private var sidebarSelection: String?
    @State private var places = DefaultPlaces.primaryPlaces()

    var body: some View {
        List(selection: $sidebarSelection) {
            Section("Places") {
                ForEach(places) { place in
                    placeRow(place)
                }
            }

            if !controller.authorizedRoots.isEmpty {
                Section("Authorized") {
                    ForEach(controller.authorizedRoots) { root in
                        placeRow(
                            title: root.title,
                            symbol: "folder.badge.person.crop",
                            target: .directory(root.url),
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
            reloadPlaces()
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
        _ place: Place,
        isAuthorized: Bool = false,
        onRemove: (() -> Void)? = nil
    ) -> some View {
        placeRow(
            title: place.title,
            symbol: place.systemImageName,
            target: place.target,
            isEjectable: place.isEjectable,
            isAuthorized: isAuthorized,
            onRemove: onRemove
        )
    }

    private func placeRow(
        title: String,
        symbol: String,
        target: PlaceTarget,
        isEjectable: Bool = false,
        isAuthorized: Bool = false,
        onRemove: (() -> Void)? = nil
    ) -> some View {
        let selectionID = target.navigationURL.absoluteString

        return HStack(spacing: 8) {
            Label(title, systemImage: symbol)
                .foregroundStyle(.primary, .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isEjectable, let fileURL = target.fileURL {
                Button {
                    ejectVolume(fileURL)
                } label: {
                    Label("Eject", systemImage: "eject")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Eject")
            }
        }
            .tag(selectionID)
            .contentShape(Rectangle())
            .onTapGesture {
                sidebarSelection = selectionID
                controller.navigate(to: target.navigationURL)
            }
            .contextMenu {
                PlaceActionMenu(
                    title: title,
                    target: target,
                    isEjectable: isEjectable,
                    isAuthorized: isAuthorized,
                    controller: controller,
                    onDetails: { detailsTarget = $0 },
                    onEject: {
                        if let fileURL = target.fileURL {
                            ejectVolume(fileURL)
                        }
                    },
                    onRemove: onRemove
                )
            }
    }

    private func reloadPlaces() {
        places = DefaultPlaces.primaryPlaces()
    }

    private func ejectVolume(_ url: URL) {
        do {
            try PlatformFileServices.ejectVolume(url)
            reloadPlaces()

            if controller.state.currentURL.isFileURL, controller.state.currentURL.path.hasPrefix(url.path) {
                controller.navigate(to: ExplorerDefaultRoot.url)
            }
        } catch {
            controller.present(error)
        }
    }

    private func syncSidebarSelection() {
        sidebarSelection = selectedSidebarPlaceID(for: controller.state.currentURL)
    }

    private func selectedSidebarPlaceID(for url: URL) -> String? {
        if !url.isFileURL {
            return places.first { $0.target.navigationURL == url }?.id
        }

        let placeCandidates: [(id: String, fileURL: URL?)] = places.map { place in
            (place.id, place.target.fileURL)
        }
        let authorizedCandidates: [(id: String, fileURL: URL?)] = controller.authorizedRoots.map { root in
            let standardizedURL = root.url.standardizedFileURL
            return (standardizedURL.absoluteString, standardizedURL)
        }
        let candidates = placeCandidates + authorizedCandidates
        let currentPath = url.standardizedFileURL.path

        return candidates
            .compactMap { id, fileURL -> (String, URL)? in
                guard let fileURL else {
                    return nil
                }

                return (id, fileURL)
            }
            .filter { _, candidate in
                currentPath == candidate.path
                    || candidate.path == "/"
                    || currentPath.hasPrefix(candidate.path + "/")
            }
            .max { left, right in
                left.1.path.count < right.1.path.count
            }?
            .0
    }
}
