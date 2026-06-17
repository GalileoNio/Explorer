import ExplorerCore
import SwiftUI
import UniformTypeIdentifiers

struct BrowserPane: View {
    @ObservedObject var controller: ExplorerController

    @State private var renameTarget: FileItem?
    @State private var pendingTransfer: TransferRequest?
    @State private var isChoosingDestination = false
    @State private var isSearchExpanded = false
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            PathBar(currentURL: controller.state.currentURL) { url in
                controller.navigate(to: url)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            ZStack {
                if controller.isLoading {
                    ProgressView()
                        .controlSize(.large)
                } else if controller.visibleItems.isEmpty {
                    ContentUnavailableView(
                        controller.state.searchQuery.isEmpty ? "No files" : "No matches",
                        systemImage: "folder",
                        description: Text(controller.state.searchQuery.isEmpty ? "This folder is empty." : "Try a different search.")
                    )
                } else {
                    content
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                controller.clearSelection()
            }
            .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                handleDrop(providers, destination: controller.state.currentURL)
            }

            StatusStrip(
                itemCount: controller.visibleItems.count,
                selectedCount: controller.state.selectedURLs.count,
                loadedAt: controller.snapshot?.loadedAt
            )
        }
        .navigationTitle(controller.state.currentURL.lastPathComponent.isEmpty ? controller.state.currentURL.path : controller.state.currentURL.lastPathComponent)
        .toolbar {
            toolbarContent
        }
        .fileImporter(
            isPresented: $isChoosingDestination,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            guard let transfer = pendingTransfer else {
                return
            }

            switch result {
            case .success(let urls):
                guard let destination = urls.first else {
                    return
                }

                switch transfer.operation {
                case .copy:
                    controller.copyItems(transfer.urls, to: destination)
                case .move:
                    controller.moveItems(transfer.urls, to: destination)
                }
            case .failure(let error):
                controller.present(error)
            }

            pendingTransfer = nil
        }
        .sheet(item: $renameTarget) { item in
            RenameSheet(item: item) { name in
                controller.rename(item, to: name)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch controller.state.viewMode {
        case .grid:
            FileGridView(
                items: controller.visibleItems,
                selectedURLs: controller.state.selectedURLs,
                controller: controller,
                onRename: { renameTarget = $0 },
                onTransfer: beginTransfer
            )
        case .list:
            FileListView(
                items: controller.visibleItems,
                selectedURLs: controller.state.selectedURLs,
                controller: controller,
                onRename: { renameTarget = $0 },
                onTransfer: beginTransfer
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                controller.goBack()
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .disabled(!controller.state.canGoBack)

            Button {
                controller.goForward()
            } label: {
                Label("Forward", systemImage: "chevron.right")
            }
            .disabled(!controller.state.canGoForward)

            Button {
                controller.navigateUp()
            } label: {
                Label("Up", systemImage: "chevron.up")
            }
        }

        ToolbarSpacer(.fixed)

        ToolbarItemGroup(placement: .primaryAction) {
            searchControl

            Menu {
                Picker("View", selection: Binding(
                    get: { controller.state.viewMode },
                    set: { controller.setViewMode($0) }
                )) {
                    Label("Grid", systemImage: "square.grid.2x2")
                        .tag(FileViewMode.grid)
                    Label("List", systemImage: "list.bullet")
                        .tag(FileViewMode.list)
                }

                Section("Sort By") {
                    sortButton("Name", key: .name)
                    sortButton("Kind", key: .kind)
                    sortButton("Size", key: .size)
                    sortButton("Modified", key: .modified)
                }

                Section("Options") {
                    Toggle(
                        "Folders First",
                        isOn: Binding(
                            get: { controller.state.sort.foldersFirst },
                            set: { controller.setFoldersFirst($0) }
                        )
                    )
                    Toggle(
                        "Show Hidden Files",
                        isOn: Binding(
                            get: { controller.state.showHiddenFiles },
                            set: { controller.setShowHiddenFiles($0) }
                        )
                    )
                }
            } label: {
                Label("View Options", systemImage: "slider.horizontal.3")
            }
            .help("View Options")

            Button {
                controller.createFolder()
            } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
            }
            .help("New Folder")
        }
    }

    @ViewBuilder
    private var searchControl: some View {
        HStack(spacing: isSearchExpanded ? 6 : 0) {
            Button {
                if isSearchExpanded {
                    isSearchFieldFocused = true
                } else {
                    withAnimation(.smooth(duration: 0.22)) {
                        isSearchExpanded = true
                    }
                    Task { @MainActor in
                        await Task.yield()
                        isSearchFieldFocused = true
                    }
                }
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .labelStyle(.iconOnly)
            .help("Search")

            HStack(spacing: 6) {
                TextField("Search current folder", text: Binding(
                    get: { controller.state.searchQuery },
                    set: { controller.setSearchQuery($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .focused($isSearchFieldFocused)
                .onSubmit {
                    if controller.state.searchQuery.isEmpty {
                        isSearchExpanded = false
                    }
                }

                Button {
                    controller.setSearchQuery("")
                    isSearchFieldFocused = false
                    withAnimation(.smooth(duration: 0.18)) {
                        isSearchExpanded = false
                    }
                } label: {
                    Label("Close Search", systemImage: "xmark")
                }
                .labelStyle(.iconOnly)
                .help("Close Search")
            }
            .frame(width: isSearchExpanded ? 258 : 0, alignment: .leading)
            .opacity(isSearchExpanded ? 1 : 0)
            .clipped()
            .allowsHitTesting(isSearchExpanded)
        }
        .animation(.smooth(duration: 0.22), value: isSearchExpanded)
    }

    private func sortButton(_ title: String, key: FileSortKey) -> some View {
        Button {
            controller.setSortKey(key)
        } label: {
            if controller.state.sort.key == key {
                Label(
                    title,
                    systemImage: controller.state.sort.direction == .ascending ? "checkmark.arrow.up" : "checkmark.arrow.down"
                )
            } else {
                Text(title)
            }
        }
    }

    private func beginTransfer(_ request: TransferRequest) {
        pendingTransfer = request
        isChoosingDestination = true
    }

    private func handleDrop(_ providers: [NSItemProvider], destination: URL) -> Bool {
        let matchingProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }

        guard !matchingProviders.isEmpty else {
            return false
        }

        for provider in matchingProviders {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let error {
                    Task { @MainActor in
                        controller.present(error)
                    }
                    return
                }

                let droppedURL: URL?
                if let url = item as? URL {
                    droppedURL = url
                } else if let data = item as? Data {
                    droppedURL = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    droppedURL = nil
                }

                if let droppedURL {
                    Task { @MainActor in
                        controller.copyItems([droppedURL], to: destination)
                    }
                }
            }
        }

        return true
    }
}

struct TransferRequest: Identifiable {
    enum Operation {
        case copy
        case move
    }

    let id = UUID()
    let operation: Operation
    let urls: [URL]
}
