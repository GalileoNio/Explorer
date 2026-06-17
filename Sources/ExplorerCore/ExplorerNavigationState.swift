import Foundation

public struct ExplorerNavigationState: Equatable, Sendable {
    public var currentURL: URL
    public var backStack: [URL]
    public var forwardStack: [URL]
    public var selectedURLs: Set<URL>
    public var searchQuery: String
    public var viewMode: FileViewMode
    public var sort: FileSort
    public var showHiddenFiles: Bool

    public init(
        currentURL: URL = ExplorerDefaultRoot.url,
        backStack: [URL] = [],
        forwardStack: [URL] = [],
        selectedURLs: Set<URL> = [],
        searchQuery: String = "",
        viewMode: FileViewMode = .grid,
        sort: FileSort = FileSort(),
        showHiddenFiles: Bool = false
    ) {
        self.currentURL = currentURL
        self.backStack = backStack
        self.forwardStack = forwardStack
        self.selectedURLs = selectedURLs
        self.searchQuery = searchQuery
        self.viewMode = viewMode
        self.sort = sort
        self.showHiddenFiles = showHiddenFiles
    }

    public var canGoBack: Bool { !backStack.isEmpty }
    public var canGoForward: Bool { !forwardStack.isEmpty }

    public mutating func navigate(to url: URL) {
        guard currentURL != url else {
            return
        }

        backStack.append(currentURL)
        forwardStack.removeAll()
        currentURL = url
        selectedURLs.removeAll()
        searchQuery = ""
    }

    public mutating func goBack() -> URL? {
        guard let previous = backStack.popLast() else {
            return nil
        }

        forwardStack.append(currentURL)
        currentURL = previous
        selectedURLs.removeAll()
        searchQuery = ""
        return previous
    }

    public mutating func goForward() -> URL? {
        guard let next = forwardStack.popLast() else {
            return nil
        }

        backStack.append(currentURL)
        currentURL = next
        selectedURLs.removeAll()
        searchQuery = ""
        return next
    }
}
