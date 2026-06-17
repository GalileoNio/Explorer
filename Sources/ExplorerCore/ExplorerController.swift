import Combine
import Foundation

#if os(macOS)
import AppKit
#endif

@MainActor
public final class ExplorerController: ObservableObject {
    @Published public private(set) var state: ExplorerNavigationState
    @Published public private(set) var snapshot: DirectorySnapshot?
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var authorizedRoots: [AuthorizedRoot]
    @Published public private(set) var clipboardOperation: ClipboardOperation?

    private let fileSystem: any FileSystemClient
    private let rootStore: AuthorizedRootStore
    private var hasStarted = false

    public init(
        initialURL: URL = ExplorerDefaultRoot.url,
        fileSystem: any FileSystemClient = LocalFileSystemClient(),
        rootStore: AuthorizedRootStore? = nil
    ) {
        let resolvedRootStore = rootStore ?? AuthorizedRootStore()
        self.state = ExplorerNavigationState(currentURL: initialURL.standardizedFileURL)
        self.fileSystem = fileSystem
        self.rootStore = resolvedRootStore
        self.authorizedRoots = resolvedRootStore.roots
    }

    public var visibleItems: [FileItem] {
        let items = snapshot?.items ?? []
        let filteredItems = FileItemSorter.filtered(items, query: state.searchQuery)
        return FileItemSorter.sorted(filteredItems, using: state.sort)
    }

    public var selectedItems: [FileItem] {
        visibleItems.filter { state.selectedURLs.contains($0.url) }
    }

    public var isCurrentDirectoryWritable: Bool {
        guard state.currentURL.isFileURL else {
            return false
        }

        return FileManager.default.isWritableFile(atPath: state.currentURL.path)
    }

    public var currentLocationTitle: String {
        if let virtualLocation = ExplorerVirtualLocation.location(for: state.currentURL) {
            return virtualLocation.title
        }

        return state.currentURL.lastPathComponent.isEmpty ? state.currentURL.path : state.currentURL.lastPathComponent
    }

    public var currentLocationSystemImageName: String {
        if let virtualLocation = ExplorerVirtualLocation.location(for: state.currentURL) {
            return virtualLocation.systemImageName
        }

        return "folder"
    }

    public func start() {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        loadCurrentDirectory()
    }

    public func loadCurrentDirectory() {
        isLoading = true
        let targetURL = state.currentURL
        let includeHidden = state.showHiddenFiles

        if let virtualLocation = ExplorerVirtualLocation.location(for: targetURL) {
            loadVirtualLocation(virtualLocation, targetURL: targetURL, includeHidden: includeHidden)
            return
        }

        Task {
            do {
                let nextSnapshot = try await fileSystem.contentsOfDirectory(at: targetURL, includeHidden: includeHidden)
                guard self.state.currentURL == targetURL else {
                    return
                }

                self.snapshot = nextSnapshot
                self.isLoading = false
            } catch {
                guard self.state.currentURL == targetURL else {
                    return
                }

                self.snapshot = DirectorySnapshot(url: targetURL, items: [])
                self.isLoading = false
                self.present(error)
            }
        }
    }

    public func navigate(to url: URL) {
        let navigationURL = normalizedNavigationURL(url)

        if navigationURL.isFileURL {
            rootStore.roots.first(where: { navigationURL.path.hasPrefix($0.url.path) }).map {
                _ = rootStore.startAccessing($0)
            }
        }

        state.navigate(to: navigationURL)
        loadCurrentDirectory()
    }

    public func navigateUp() {
        guard state.currentURL.isFileURL else {
            return
        }

        let parent = state.currentURL.deletingLastPathComponent()
        guard parent != state.currentURL else {
            return
        }

        navigate(to: parent)
    }

    public func goBack() {
        guard state.goBack() != nil else {
            return
        }

        loadCurrentDirectory()
    }

    public func goForward() {
        guard state.goForward() != nil else {
            return
        }

        loadCurrentDirectory()
    }

    public func setSearchQuery(_ query: String) {
        state.searchQuery = query
    }

    public func setViewMode(_ viewMode: FileViewMode) {
        state.viewMode = viewMode
    }

    public func setSortKey(_ key: FileSortKey) {
        if state.sort.key == key {
            state.sort.direction = state.sort.direction == .ascending ? .descending : .ascending
        } else {
            state.sort.key = key
            state.sort.direction = .ascending
        }
    }

    public func setFoldersFirst(_ foldersFirst: Bool) {
        state.sort.foldersFirst = foldersFirst
    }

    public func setShowHiddenFiles(_ showHiddenFiles: Bool) {
        state.showHiddenFiles = showHiddenFiles
        loadCurrentDirectory()
    }

    public func setIconSize(_ iconSize: Double) {
        state.iconSize = min(max(iconSize, 28), 80)
    }

    public func select(_ item: FileItem, extending: Bool = false) {
        if extending {
            if state.selectedURLs.contains(item.url) {
                state.selectedURLs.remove(item.url)
            } else {
                state.selectedURLs.insert(item.url)
            }
        } else {
            state.selectedURLs = [item.url]
        }
    }

    public func clearSelection() {
        state.selectedURLs.removeAll()
    }

    public func setSelectedURLs(_ urls: Set<URL>) {
        state.selectedURLs = urls
    }

    public func selectAllVisibleItems() {
        state.selectedURLs = Set(visibleItems.map(\.url))
    }

    public func selectedItems(containing item: FileItem) -> [FileItem] {
        if state.selectedURLs.contains(item.url) {
            return selectedItems
        }

        return [item]
    }

    public func selectedURLs(containing item: FileItem) -> [URL] {
        selectedItems(containing: item).map(\.url)
    }

    public func details(for item: FileItem) async throws -> FileItemDetails {
        try await fileSystem.detailsOfItem(at: item.url)
    }

    public func addAuthorizedRoot(_ url: URL) {
        let root = rootStore.add(url: url)
        _ = rootStore.startAccessing(root)
        authorizedRoots = rootStore.roots
    }

    public func removeAuthorizedRoot(_ root: AuthorizedRoot) {
        rootStore.remove(root)
        authorizedRoots = rootStore.roots
    }

    public func createFolder() {
        guard state.currentURL.isFileURL else {
            return
        }

        Task {
            do {
                let newURL = try await fileSystem.createFolder(named: "Untitled Folder", in: state.currentURL)
                state.selectedURLs = [newURL]
                loadCurrentDirectory()
            } catch {
                present(error)
            }
        }
    }

    public func rename(_ item: FileItem, to newName: String) {
        Task {
            do {
                let renamedURL = try await fileSystem.renameItem(at: item.url, to: newName)
                state.selectedURLs = [renamedURL]
                loadCurrentDirectory()
            } catch {
                present(error)
            }
        }
    }

    public func duplicate(_ item: FileItem) {
        duplicate([item])
    }

    public func duplicate(_ items: [FileItem]) {
        let urls = items.map(\.url)
        guard !urls.isEmpty else {
            return
        }

        Task {
            do {
                let duplicatedURLs = try await fileSystem.duplicateItems(urls)
                state.selectedURLs = Set(duplicatedURLs)
                loadCurrentDirectory()
            } catch {
                present(error)
            }
        }
    }

    public func setClipboardOperation(_ operation: ClipboardOperation) {
        clipboardOperation = operation
    }

    public func clearClipboardOperation() {
        clipboardOperation = nil
    }

    public func copyItems(_ urls: [URL], to destination: URL) {
        guard destination.isFileURL else {
            return
        }

        Task {
            do {
                let copiedURLs = try await fileSystem.copyItems(urls, to: destination)
                state.selectedURLs = Set(copiedURLs)
                loadCurrentDirectory()
            } catch {
                present(error)
            }
        }
    }

    public func moveItems(_ urls: [URL], to destination: URL) {
        guard destination.isFileURL else {
            return
        }

        Task {
            do {
                let movedURLs = try await fileSystem.moveItems(urls, to: destination)
                state.selectedURLs = Set(movedURLs)
                loadCurrentDirectory()
            } catch {
                present(error)
            }
        }
    }

    public func pasteItems(_ urls: [URL], operation: ClipboardOperationKind, to destination: URL) {
        guard !urls.isEmpty else {
            return
        }

        switch operation {
        case .copy:
            copyItems(urls, to: destination)
        case .move:
            moveItems(urls, to: destination)
            clearClipboardOperation()
        }
    }

    public func trash(_ items: [FileItem]) {
        let urls = items.map(\.url)
        Task {
            do {
                try await fileSystem.trashItems(urls)
                state.selectedURLs.subtract(urls)
                loadCurrentDirectory()
            } catch {
                present(error)
            }
        }
    }

    public func present(_ error: Error) {
        if let explorerError = error as? ExplorerError {
            errorMessage = explorerError.errorDescription
        } else {
            errorMessage = (error as NSError).localizedDescription
        }
    }

    public func clearError() {
        errorMessage = nil
    }

    private func loadVirtualLocation(
        _ virtualLocation: ExplorerVirtualLocation,
        targetURL: URL,
        includeHidden: Bool
    ) {
        Task {
            let items = Self.items(for: virtualLocation, includeHidden: includeHidden)
            guard self.state.currentURL == targetURL else {
                return
            }

            self.snapshot = DirectorySnapshot(url: targetURL, items: items)
            self.isLoading = false
        }
    }

    private static func items(for virtualLocation: ExplorerVirtualLocation, includeHidden: Bool) -> [FileItem] {
        switch virtualLocation {
        case .recents:
            return SystemRecentItems.urls()
                .reduce(into: [URL]()) { urls, url in
                    let standardizedURL = normalizedNavigationURL(url)
                    guard standardizedURL.isFileURL, !urls.contains(standardizedURL) else {
                        return
                    }

                    urls.append(standardizedURL)
                }
                .compactMap { url in
                    (try? FileItem.make(url: url)) ?? FileItem.fallback(url: url)
                }
                .filter { includeHidden || !$0.isHidden }
        }
    }

    private static func normalizedNavigationURL(_ url: URL) -> URL {
        url.isFileURL ? url.standardizedFileURL : url
    }

    private func normalizedNavigationURL(_ url: URL) -> URL {
        Self.normalizedNavigationURL(url)
    }
}

@MainActor
public enum SystemRecentItems {
    public static func urls() -> [URL] {
        #if os(macOS)
        NSDocumentController.shared.recentDocumentURLs
            .filter(\.isFileURL)
            .map(\.standardizedFileURL)
        #else
        []
        #endif
    }

    public static func note(_ url: URL) {
        guard url.isFileURL else {
            return
        }

        #if os(macOS)
        NSDocumentController.shared.noteNewRecentDocumentURL(url.standardizedFileURL)
        #endif
    }
}
