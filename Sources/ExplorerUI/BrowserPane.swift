import ExplorerCore
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

public enum ExplorerPreferenceKeys {
    public static let pathBarInTitleBar = "ExplorerPathBarInTitleBar"
}

struct BrowserPane: View {
    @ObservedObject var controller: ExplorerController

    @State private var renameTarget: FileItem?
    @State private var detailsTarget: FileItem?
    @State private var pendingTransfer: TransferRequest?
    @State private var isChoosingDestination = false
    @State private var isSearchExpanded = false
    @AppStorage(ExplorerPreferenceKeys.pathBarInTitleBar) private var pathBarInTitleBar = false
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if !pathBarInTitleBar {
                pathBar()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }

            ZStack(alignment: .topLeading) {
                if controller.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .controlSize(.large)
                } else if controller.visibleItems.isEmpty {
                    ContentUnavailableView(
                        emptyContentTitle,
                        systemImage: controller.currentLocationSystemImageName,
                        description: Text(emptyContentDescription)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .contextMenu {
                FileBackgroundActionMenu(controller: controller) { item in
                    detailsTarget = item
                }
            }
            .onTapGesture {
                controller.clearSelection()
            }
            .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                handleDrop(providers, destination: controller.state.currentURL)
            }

            StatusStrip(
                itemCount: controller.visibleItems.count,
                selectedCount: controller.state.selectedURLs.count,
                loadedAt: controller.snapshot?.loadedAt,
                iconSize: Binding(
                    get: { controller.state.iconSize },
                    set: { controller.setIconSize($0) }
                )
            )
        }
        .navigationTitle(navigationTitle)
        .windowTitle(navigationTitle)
        .toolbar {
            toolbarContent
        }
        .focusedSceneValue(\.explorerActions, focusedActions)
        .onAppear {
            controller.start()
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
        .sheet(item: $detailsTarget) { item in
            FileInfoSheet(item: item, controller: controller)
        }
    }

    private var navigationTitle: String {
        controller.currentLocationTitle
    }

    private var emptyContentTitle: String {
        if !controller.state.searchQuery.isEmpty {
            return "No matches"
        }

        if ExplorerVirtualLocation.location(for: controller.state.currentURL) == .recents {
            return "No Recent Items"
        }

        return "No files"
    }

    private var emptyContentDescription: String {
        if !controller.state.searchQuery.isEmpty {
            return "Try a different search."
        }

        if ExplorerVirtualLocation.location(for: controller.state.currentURL) == .recents {
            return "Files opened from Explorer will appear here."
        }

        return "This folder is empty."
    }

    private func pathBar() -> some View {
        PathBar(currentURL: controller.state.currentURL) { url in
            controller.navigate(to: url)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch controller.state.viewMode {
        case .grid:
            FileGridView(
                items: controller.visibleItems,
                selectedURLs: controller.state.selectedURLs,
                iconSize: CGFloat(controller.state.iconSize),
                controller: controller,
                onRename: { renameTarget = $0 },
                onDetails: { detailsTarget = $0 },
                onTransfer: beginTransfer
            )
        case .list:
            FileListView(
                items: controller.visibleItems,
                selectedURLs: controller.state.selectedURLs,
                iconSize: CGFloat(controller.state.iconSize),
                controller: controller,
                onRename: { renameTarget = $0 },
                onDetails: { detailsTarget = $0 },
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
            .disabled(!controller.state.currentURL.isFileURL)
        }

        if pathBarInTitleBar {
            ToolbarItem(placement: .principal) {
                titleBarPathBar
            }
        } else {
            ToolbarSpacer(.fixed)
        }

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
                    Toggle("Address Bar in Title Bar", isOn: $pathBarInTitleBar)
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
            .disabled(!controller.isCurrentDirectoryWritable)
        }
    }

    @ViewBuilder
    private var titleBarPathBar: some View {
        #if os(macOS)
        ExpandingToolbarView {
            pathBar()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        #else
        pathBar()
            .frame(maxWidth: .infinity, alignment: .leading)
        #endif
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
                    systemImage: controller.state.sort.direction == .ascending ? "arrow.up" : "arrow.down"
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

    private var focusedActions: ExplorerFocusedActions {
        ExplorerFocusedActions(
            renameSelection: renameSelectedItem,
            showInfoForSelection: showInfoForSelectedItem,
            copySelection: { copySelectedItems(operation: .copy) },
            cutSelection: { copySelectedItems(operation: .move) },
            paste: pasteIntoCurrentDirectory,
            quickLookSelection: quickLookSelectedItems,
            revealSelection: revealSelectedItems,
            trashSelection: trashSelectedItems,
            selectAll: {
                controller.selectAllVisibleItems()
            },
            createFolder: {
                controller.createFolder()
            }
        )
    }

    private func renameSelectedItem() {
        guard controller.selectedItems.count == 1, let item = controller.selectedItems.first else {
            return
        }

        renameTarget = item
    }

    private func showInfoForSelectedItem() {
        guard controller.selectedItems.count == 1, let item = controller.selectedItems.first else {
            return
        }

        detailsTarget = item
    }

    private func copySelectedItems(operation: ClipboardOperationKind) {
        FileActionPerformer.copy(
            urls: controller.selectedItems.map(\.url),
            operation: operation,
            controller: controller
        )
    }

    private func pasteIntoCurrentDirectory() {
        guard controller.state.currentURL.isFileURL else {
            return
        }

        FileActionPerformer.paste(
            context: FileActionPerformer.context(controller: controller, selectedItems: []),
            controller: controller
        )
    }

    private func quickLookSelectedItems() {
        PlatformFileServices.quickLookItems(controller.selectedItems.map(\.url))
    }

    private func revealSelectedItems() {
        PlatformFileServices.revealItems(controller.selectedItems.map(\.url))
    }

    private func trashSelectedItems() {
        controller.trash(controller.selectedItems)
    }

    private func handleDrop(_ providers: [NSItemProvider], destination: URL) -> Bool {
        guard destination.isFileURL else {
            return false
        }

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

private extension View {
    @ViewBuilder
    func windowTitle(_ title: String) -> some View {
        #if os(macOS)
        background(WindowTitleWriter(title: title))
        #else
        self
        #endif
    }
}

#if os(macOS)
private struct ExpandingToolbarView<Content: View>: NSViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeNSView(context: Context) -> ExpandingToolbarContainer<Content> {
        ExpandingToolbarContainer(rootView: content)
    }

    func updateNSView(_ nsView: ExpandingToolbarContainer<Content>, context: Context) {
        nsView.update(rootView: content)
    }
}

private final class ExpandingToolbarContainer<Content: View>: NSView {
    private let hostingView: NSHostingView<Content>

    override var intrinsicContentSize: NSSize {
        let hostingSize = hostingView.intrinsicContentSize
        return NSSize(width: NSView.noIntrinsicMetric, height: hostingSize.height)
    }

    init(rootView: Content) {
        self.hostingView = NSHostingView(rootView: rootView)
        super.init(frame: .zero)

        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        hostingView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        hostingView.setContentHuggingPriority(.required, for: .vertical)
        hostingView.setContentCompressionResistancePriority(.required, for: .vertical)

        addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(rootView: Content) {
        hostingView.rootView = rootView
        invalidateIntrinsicContentSize()
    }
}

private struct WindowTitleWriter: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in
            guard let window = nsView?.window else {
                return
            }

            if window.title != title {
                window.title = title
            }

            if window.titleVisibility != .visible {
                window.titleVisibility = .visible
            }
        }
    }
}
#endif
