import Combine
import Foundation

@MainActor
public final class ExplorerController: ObservableObject {
    @Published public private(set) var state: ExplorerNavigationState
    @Published public private(set) var snapshot: DirectorySnapshot?
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var authorizedRoots: [AuthorizedRoot]

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
        rootStore.roots.first(where: { url.path.hasPrefix($0.url.path) }).map {
            _ = rootStore.startAccessing($0)
        }

        state.navigate(to: url.standardizedFileURL)
        loadCurrentDirectory()
    }

    public func navigateUp() {
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
        Task {
            do {
                let duplicatedURL = try await fileSystem.duplicateItem(at: item.url)
                state.selectedURLs = [duplicatedURL]
                loadCurrentDirectory()
            } catch {
                present(error)
            }
        }
    }

    public func copyItems(_ urls: [URL], to destination: URL) {
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
}
