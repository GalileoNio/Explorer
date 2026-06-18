import ExplorerCore
import SwiftUI

public struct ExplorerFocusedActions {
    public let renameSelection: () -> Void
    public let showInfoForSelection: () -> Void
    public let copySelection: () -> Void
    public let cutSelection: () -> Void
    public let paste: () -> Void
    public let quickLookSelection: () -> Void
    public let revealSelection: () -> Void
    public let trashSelection: () -> Void
    public let selectAll: () -> Void
    public let createFolder: () -> Void

    public init(
        renameSelection: @escaping () -> Void,
        showInfoForSelection: @escaping () -> Void,
        copySelection: @escaping () -> Void,
        cutSelection: @escaping () -> Void,
        paste: @escaping () -> Void,
        quickLookSelection: @escaping () -> Void,
        revealSelection: @escaping () -> Void,
        trashSelection: @escaping () -> Void,
        selectAll: @escaping () -> Void,
        createFolder: @escaping () -> Void
    ) {
        self.renameSelection = renameSelection
        self.showInfoForSelection = showInfoForSelection
        self.copySelection = copySelection
        self.cutSelection = cutSelection
        self.paste = paste
        self.quickLookSelection = quickLookSelection
        self.revealSelection = revealSelection
        self.trashSelection = trashSelection
        self.selectAll = selectAll
        self.createFolder = createFolder
    }
}

private struct ExplorerFocusedActionsKey: FocusedValueKey {
    typealias Value = ExplorerFocusedActions
}

public extension FocusedValues {
    var explorerActions: ExplorerFocusedActions? {
        get { self[ExplorerFocusedActionsKey.self] }
        set { self[ExplorerFocusedActionsKey.self] = newValue }
    }
}

struct FileActionMenu: View {
    let item: FileItem
    let selectedItems: [FileItem]
    let controller: ExplorerController
    let onRename: (FileItem) -> Void
    let onDetails: (FileItem) -> Void
    let onTransfer: (TransferRequest) -> Void

    private var context: FileActionContext {
        FileActionPerformer.context(
            controller: controller,
            clickedItem: item,
            selectedItems: selectedItems
        )
    }

    private var availability: FileActionAvailability {
        FileActionAvailability(context: context)
    }

    var body: some View {
        Button(openTitle, systemImage: item.isNavigable && context.actedItems.count == 1 ? "folder" : "arrow.up.forward.app") {
            FileActionPerformer.open(items: context.actedItems, controller: controller)
        }
        .disabled(!availability.canOpen)

        #if os(macOS)
        if let singleItem = context.singleActedItem {
            let applications = PlatformFileServices.applicationsThatCanOpen(singleItem.url)
            if !applications.isEmpty {
                Menu {
                    ForEach(applications) { application in
                        Button(application.name) {
                            PlatformFileServices.open([singleItem.url], with: application)
                        }
                    }
                } label: {
                    Label("Open With", systemImage: "arrow.up.forward.app")
                }
                .disabled(!availability.canOpenWith)
            }
        }
        #endif

        Button("Quick Look", systemImage: "eye") {
            PlatformFileServices.quickLookItems(context.actedURLs)
        }
        .disabled(!availability.canQuickLook)

        Button("Get Info", systemImage: "info.circle") {
            if let item = context.singleActedItem {
                onDetails(item)
            }
        }
        .disabled(!availability.canGetInfo)

        Divider()

        Button("Rename", systemImage: "pencil") {
            if let item = context.singleActedItem {
                onRename(item)
            }
        }
        .disabled(!availability.canRename)

        Button("Duplicate", systemImage: "plus.square.on.square") {
            controller.duplicate(context.actedItems)
        }
        .disabled(!availability.canDuplicate)

        Divider()

        Button("Copy", systemImage: "doc.on.doc") {
            FileActionPerformer.copy(urls: context.actedURLs, operation: .copy, controller: controller)
        }
        .disabled(!availability.canCopy)

        Button("Cut", systemImage: "scissors") {
            FileActionPerformer.copy(urls: context.actedURLs, operation: .move, controller: controller)
        }
        .disabled(!availability.canCut)

        if item.isNavigable {
            Button("Paste Into \"\(item.name)\"", systemImage: "doc.on.clipboard") {
                FileActionPerformer.paste(context: context, controller: controller)
            }
            .disabled(!availability.canPasteIntoTarget)
        }

        Button("Copy To...", systemImage: "folder.badge.plus") {
            onTransfer(TransferRequest(operation: .copy, urls: context.actedURLs))
        }
        .disabled(!availability.canTransfer)

        Button("Move To...", systemImage: "folder") {
            onTransfer(TransferRequest(operation: .move, urls: context.actedURLs))
        }
        .disabled(!availability.canTransfer)

        Divider()

        Button("Share...", systemImage: "square.and.arrow.up") {
            PlatformFileServices.shareItems(context.actedURLs)
        }
        .disabled(!availability.canShare)

        #if os(macOS)
        Button("Reveal in Finder", systemImage: "finder") {
            PlatformFileServices.revealItems(context.actedURLs)
        }
        .disabled(!availability.canRevealInFinder)
        #endif

        Menu {
            Button("Name") {
                FileActionPerformer.copyNames(context.actedItems)
            }
            .disabled(!availability.canCopyName)

            Button("Path") {
                FileActionPerformer.copyPaths(context.actedURLs)
            }
            .disabled(!availability.canCopyPath)

            Button("File URL") {
                FileActionPerformer.copyFileURLText(context.actedURLs)
            }
            .disabled(!availability.canCopyFileURL)
        } label: {
            Label("Copy As", systemImage: "doc.on.doc")
        }

        Divider()

        Button("Move to Trash", systemImage: "trash", role: .destructive) {
            controller.trash(context.actedItems)
        }
        .disabled(!availability.canTrash)
    }

    private var openTitle: String {
        let count = context.actedItems.count
        return count > 1 ? "Open \(count) Items" : "Open"
    }
}

struct FileBackgroundActionMenu: View {
    let controller: ExplorerController
    let onDetails: (FileItem) -> Void

    private var context: FileActionContext {
        FileActionPerformer.context(controller: controller)
    }

    private var availability: FileActionAvailability {
        FileActionAvailability(context: context)
    }

    var body: some View {
        Button("New Folder", systemImage: "folder.badge.plus") {
            controller.createFolder()
        }
        .disabled(!availability.canCreateFolder)

        Button("Paste", systemImage: "doc.on.clipboard") {
            FileActionPerformer.paste(context: context, controller: controller)
        }
        .disabled(!availability.canPaste)

        Button("Select All", systemImage: "checkmark.circle") {
            controller.selectAllVisibleItems()
        }
        .disabled(!availability.canSelectAll)

        Divider()

        Menu {
            viewModeButton("Grid", mode: .grid, symbol: "square.grid.2x2")
            viewModeButton("List", mode: .list, symbol: "list.bullet")
        } label: {
            Label("View As", systemImage: "rectangle.grid.2x2")
        }

        Menu {
            sortButton("Name", key: .name)
            sortButton("Kind", key: .kind)
            sortButton("Size", key: .size)
            sortButton("Modified", key: .modified)
        } label: {
            Label("Sort By", systemImage: "arrow.up.arrow.down")
        }

        Toggle("Show Hidden Files", isOn: Binding(
            get: { controller.state.showHiddenFiles },
            set: { controller.setShowHiddenFiles($0) }
        ))

        Divider()

        if controller.state.currentURL.isFileURL {
            Button("Get Info", systemImage: "info.circle") {
                onDetails(currentFolderItem)
            }

            #if os(macOS)
            Button("Reveal in Finder", systemImage: "finder") {
                PlatformFileServices.reveal(controller.state.currentURL)
            }
            #endif

            Button("Copy Current Folder Path", systemImage: "doc.on.doc") {
                PlatformFileServices.copyTextToPasteboard(controller.state.currentURL.path)
            }
        }
    }

    private var currentFolderItem: FileItem {
        (try? FileItem.make(url: controller.state.currentURL)) ?? FileItem.fallback(url: controller.state.currentURL)
    }

    private func viewModeButton(_ title: String, mode: FileViewMode, symbol: String) -> some View {
        Button {
            controller.setViewMode(mode)
        } label: {
            if controller.state.viewMode == mode {
                Label(title, systemImage: "checkmark")
            } else {
                Label(title, systemImage: symbol)
            }
        }
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
}

struct PlaceActionMenu: View {
    let title: String
    let target: PlaceTarget
    let isEjectable: Bool
    let isAuthorized: Bool
    let controller: ExplorerController
    let onDetails: (FileItem) -> Void
    let onEject: () -> Void
    let onRemove: (() -> Void)?

    var body: some View {
        Button("Open", systemImage: "folder") {
            controller.navigate(to: target.navigationURL)
        }

        if let fileURL = target.fileURL {
            Button("Get Info", systemImage: "info.circle") {
                onDetails(placeItem(for: fileURL))
            }

            Button("Copy Path", systemImage: "doc.on.doc") {
                PlatformFileServices.copyTextToPasteboard(fileURL.path)
            }

            #if os(macOS)
            Button("Reveal in Finder", systemImage: "finder") {
                PlatformFileServices.reveal(fileURL)
            }
            #endif

            if isEjectable {
                Button("Eject", systemImage: "eject") {
                    onEject()
                }
            }
        }

        if isAuthorized, let onRemove {
            Divider()

            Button("Remove from Sidebar", systemImage: "minus.circle", role: .destructive) {
                onRemove()
            }
        }
    }

    private func placeItem(for url: URL) -> FileItem {
        (try? FileItem.make(url: url)) ?? FileItem.fallback(url: url)
    }
}

@MainActor
enum FileActionPerformer {
    static func context(
        controller: ExplorerController,
        clickedItem: FileItem? = nil,
        selectedItems: [FileItem]? = nil
    ) -> FileActionContext {
        let pasteboardURLs = PlatformFileServices.readPasteboardFileURLs()
        let clipboardOperation = effectiveClipboardOperation(
            controller.clipboardOperation,
            pasteboardURLs: pasteboardURLs
        )

        return FileActionContext(
            currentDirectory: controller.state.currentURL,
            clickedItem: clickedItem,
            selectedItems: selectedItems ?? controller.selectedItems,
            visibleItemCount: controller.visibleItems.count,
            pasteboardURLs: pasteboardURLs,
            clipboardOperation: clipboardOperation,
            isCurrentDirectoryWritable: controller.isCurrentDirectoryWritable
        )
    }

    static func open(items: [FileItem], controller: ExplorerController) {
        guard !items.isEmpty else {
            return
        }

        if items.count == 1, let item = items.first, item.isNavigable {
            controller.navigate(to: item.url)
        } else {
            PlatformFileServices.openItems(items.map(\.url))
        }
    }

    static func copy(urls: [URL], operation: ClipboardOperationKind, controller: ExplorerController) {
        guard !urls.isEmpty else {
            return
        }

        controller.setClipboardOperation(ClipboardOperation(kind: operation, urls: urls))
        PlatformFileServices.copyFileURLsToPasteboard(urls)
    }

    static func paste(context: FileActionContext, controller: ExplorerController) {
        controller.pasteItems(
            context.pasteURLs,
            operation: context.resolvedPasteOperation,
            to: context.pasteDestination
        )
    }

    static func copyNames(_ items: [FileItem]) {
        PlatformFileServices.copyTextToPasteboard(items.map(\.name).joined(separator: "\n"))
    }

    static func copyPaths(_ urls: [URL]) {
        PlatformFileServices.copyTextToPasteboard(urls.map(\.path).joined(separator: "\n"))
    }

    static func copyFileURLText(_ urls: [URL]) {
        PlatformFileServices.copyTextToPasteboard(urls.map(\.absoluteString).joined(separator: "\n"))
    }

    private static func effectiveClipboardOperation(
        _ operation: ClipboardOperation?,
        pasteboardURLs: [URL]
    ) -> ClipboardOperation? {
        guard let operation else {
            return nil
        }

        guard !pasteboardURLs.isEmpty else {
            return operation
        }

        return Set(operation.urls) == Set(pasteboardURLs) ? operation : nil
    }
}
