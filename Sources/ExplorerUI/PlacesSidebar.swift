import ExplorerCore
import SwiftUI
import UniformTypeIdentifiers

struct PlacesSidebar: View {
    @ObservedObject var controller: ExplorerController
    @State private var accessPicker: AccessPicker?
    @State private var detailsTarget: FileItem?
    @State private var places = DefaultPlaces.primaryPlaces()

    var body: some View {
        List(selection: sidebarSelection) {
            Section("Places") {
                ForEach(places) { place in
                    placeRow(place)
                }
            }

            if !controller.authorizedRoots.isEmpty {
                Section("Authorized") {
                    ForEach(controller.authorizedRoots) { root in
                        authorizedRootRow(root)
                    }
                }
            }

            Section("Access") {
                addFolderRow
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Explorer")
        .onAppear {
            reloadPlaces()
        }
        .fileImporter(
            isPresented: accessPickerBinding,
            allowedContentTypes: accessPicker?.allowedContentTypes ?? [.folder],
            allowsMultipleSelection: false
        ) { result in
            defer {
                accessPicker = nil
            }

            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    return
                }

                let root = controller.addAuthorizedRoot(url)
                if root.isDirectory {
                    controller.navigate(to: root.url)
                }
            case .failure(let error):
                if !isUserCancelled(error) {
                    controller.present(error)
                }
            }
        }
        .sheet(item: $detailsTarget) { item in
            FileInfoSheet(item: item, controller: controller)
        }
    }

    private var sidebarSelection: Binding<String?> {
        Binding(
            get: {
                selectedSidebarPlaceID(for: controller.state.currentURL)
            },
            set: { selectionID in
                guard let selectionID else {
                    return
                }

                navigateToSidebarSelection(selectionID)
            }
        )
    }

    private var accessPickerBinding: Binding<Bool> {
        Binding(
            get: { accessPicker != nil },
            set: { isPresented in
                if !isPresented {
                    accessPicker = nil
                }
            }
        )
    }

    private var addFolderRow: some View {
        Group {
            Button {
                accessPicker = .folder
            } label: {
                Label("Add Folder...", systemImage: "folder.badge.plus")
            }

            Button {
                accessPicker = .file
            } label: {
                Label("Add File...", systemImage: "doc.badge.plus")
            }
        }
    }

    @ViewBuilder
    private func authorizedRootRow(_ root: AuthorizedRoot) -> some View {
        if root.isDirectory {
            placeRow(
                title: root.title,
                symbol: root.kind.systemImageName,
                target: .directory(root.url),
                isAuthorized: true,
                onRemove: {
                    controller.removeAuthorizedRoot(root)
                }
            )
        } else {
            authorizedFileRow(root)
        }
    }

    private func authorizedFileRow(_ root: AuthorizedRoot) -> some View {
        Button {
            openAuthorizedFile(root)
        } label: {
            Label(root.title, systemImage: root.kind.systemImageName)
        }
        .contextMenu {
            Button("Open", systemImage: "arrow.up.forward.app") {
                openAuthorizedFile(root)
            }

            Button("Quick Look", systemImage: "eye") {
                if controller.startAccessing(root) {
                    PlatformFileServices.quickLookItems([root.url])
                }
            }

            Button("Get Info", systemImage: "info.circle") {
                detailsTarget = fileItem(for: root.url)
            }

            Button("Copy Path", systemImage: "doc.on.doc") {
                PlatformFileServices.copyTextToPasteboard(root.url.path)
            }

            #if os(macOS)
            Button("Reveal in Finder", systemImage: "finder") {
                PlatformFileServices.reveal(root.url)
            }
            #endif

            Divider()

            Button("Remove from Sidebar", systemImage: "minus.circle", role: .destructive) {
                controller.removeAuthorizedRoot(root)
            }
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
        let selectionID = sidebarSelectionID(for: target)

        return HStack(spacing: 8) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture().onEnded {
                        navigate(to: target.navigationURL)
                    }
                )

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

    private func navigateToSidebarSelection(_ selectionID: String) {
        guard let url = navigationURL(forSidebarSelection: selectionID) else {
            return
        }

        navigate(to: url)
    }

    private func navigate(to url: URL) {
        guard controller.state.currentURL != url else {
            return
        }

        controller.navigate(to: url)
    }

    private func openAuthorizedFile(_ root: AuthorizedRoot) {
        guard controller.startAccessing(root) else {
            controller.present(ExplorerError.permissionDenied(root.url))
            return
        }

        PlatformFileServices.open(root.url)
    }

    private func navigationURL(forSidebarSelection selectionID: String) -> URL? {
        if let place = places.first(where: { sidebarSelectionID(for: $0.target) == selectionID }) {
            return place.target.navigationURL
        }

        return controller.authorizedRoots
            .filter(\.isDirectory)
            .map { $0.url.standardizedFileURL }
            .first { $0.absoluteString == selectionID }
    }

    private func sidebarSelectionID(for target: PlaceTarget) -> String {
        target.navigationURL.absoluteString
    }

    private func selectedSidebarPlaceID(for url: URL) -> String? {
        if !url.isFileURL {
            return places.first { $0.target.navigationURL == url }.map { sidebarSelectionID(for: $0.target) }
        }

        let placeCandidates: [(id: String, fileURL: URL?)] = places.map { place in
            (sidebarSelectionID(for: place.target), place.target.fileURL)
        }
        let authorizedCandidates: [(id: String, fileURL: URL?)] = controller.authorizedRoots.map { root in
            let standardizedURL = root.url.standardizedFileURL
            return (standardizedURL.absoluteString, root.isDirectory ? standardizedURL : nil)
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

    private func fileItem(for url: URL) -> FileItem {
        (try? FileItem.make(url: url)) ?? FileItem.fallback(url: url)
    }

    private func isUserCancelled(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError
    }
}

private enum AccessPicker: Identifiable {
    case folder
    case file

    var id: String {
        switch self {
        case .folder:
            return "folder"
        case .file:
            return "file"
        }
    }

    var allowedContentTypes: [UTType] {
        switch self {
        case .folder:
            return [.folder]
        case .file:
            return [.item]
        }
    }
}
