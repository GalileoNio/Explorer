import Foundation

public enum ClipboardOperationKind: String, Codable, Sendable {
    case copy
    case move
}

public struct ClipboardOperation: Equatable, Sendable {
    public let kind: ClipboardOperationKind
    public let urls: [URL]

    public init(kind: ClipboardOperationKind, urls: [URL]) {
        self.kind = kind
        self.urls = urls.map(\.standardizedFileURL)
    }
}

public struct FileActionContext: Equatable, Sendable {
    public let currentDirectory: URL
    public let clickedItem: FileItem?
    public let selectedItems: [FileItem]
    public let visibleItemCount: Int
    public let pasteboardURLs: [URL]
    public let clipboardOperation: ClipboardOperation?
    public let isCurrentDirectoryWritable: Bool

    public init(
        currentDirectory: URL,
        clickedItem: FileItem? = nil,
        selectedItems: [FileItem] = [],
        visibleItemCount: Int = 0,
        pasteboardURLs: [URL] = [],
        clipboardOperation: ClipboardOperation? = nil,
        isCurrentDirectoryWritable: Bool = true
    ) {
        self.currentDirectory = currentDirectory.isFileURL ? currentDirectory.standardizedFileURL : currentDirectory
        self.clickedItem = clickedItem
        self.selectedItems = selectedItems
        self.visibleItemCount = visibleItemCount
        self.pasteboardURLs = pasteboardURLs.map(\.standardizedFileURL)
        self.clipboardOperation = clipboardOperation
        self.isCurrentDirectoryWritable = isCurrentDirectoryWritable
    }

    public var actedItems: [FileItem] {
        guard let clickedItem else {
            return selectedItems
        }

        if selectedItems.contains(where: { $0.url == clickedItem.url }) {
            return selectedItems
        }

        return [clickedItem]
    }

    public var actedURLs: [URL] {
        actedItems.map(\.url)
    }

    public var singleActedItem: FileItem? {
        actedItems.count == 1 ? actedItems[0] : nil
    }

    public var pasteURLs: [URL] {
        if let clipboardOperation, !clipboardOperation.urls.isEmpty {
            return clipboardOperation.urls
        }

        return pasteboardURLs
    }

    public var resolvedPasteOperation: ClipboardOperationKind {
        clipboardOperation?.kind ?? .copy
    }

    public var pasteDestination: URL {
        if let clickedItem, clickedItem.isNavigable {
            return clickedItem.url
        }

        return currentDirectory
    }
}

public struct FileActionAvailability: Equatable, Sendable {
    public let canOpen: Bool
    public let canOpenWith: Bool
    public let canQuickLook: Bool
    public let canGetInfo: Bool
    public let canRename: Bool
    public let canDuplicate: Bool
    public let canCopy: Bool
    public let canCut: Bool
    public let canPaste: Bool
    public let canPasteIntoTarget: Bool
    public let canTransfer: Bool
    public let canShare: Bool
    public let canRevealInFinder: Bool
    public let canCopyName: Bool
    public let canCopyPath: Bool
    public let canCopyFileURL: Bool
    public let canTrash: Bool
    public let canCreateFolder: Bool
    public let canSelectAll: Bool

    public init(context: FileActionContext) {
        let actedItems = context.actedItems
        let hasActedItems = !actedItems.isEmpty
        let hasPasteURLs = !context.pasteURLs.isEmpty
        let hasSingleItem = context.singleActedItem != nil

        canOpen = hasActedItems
        #if os(macOS)
        canOpenWith = hasSingleItem
        canRevealInFinder = hasActedItems
        #else
        canOpenWith = false
        canRevealInFinder = false
        #endif
        canQuickLook = hasActedItems
        canGetInfo = hasSingleItem
        canRename = hasSingleItem && context.isCurrentDirectoryWritable
        canDuplicate = hasActedItems && context.isCurrentDirectoryWritable
        canCopy = hasActedItems
        canCut = hasActedItems
        canPaste = hasPasteURLs && context.isCurrentDirectoryWritable
        canPasteIntoTarget = context.clickedItem?.isNavigable == true && hasPasteURLs
        canTransfer = hasActedItems
        canShare = hasActedItems
        canCopyName = hasActedItems
        canCopyPath = hasActedItems
        canCopyFileURL = hasActedItems
        canTrash = hasActedItems
        canCreateFolder = context.isCurrentDirectoryWritable
        canSelectAll = context.visibleItemCount > 0
    }
}
