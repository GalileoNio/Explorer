import Combine
import Foundation

public struct AuthorizedRoot: Identifiable, Hashable, Codable, Sendable {
    public let title: String
    public let url: URL
    public let bookmarkData: Data?

    public var id: String { url.path }

    public init(title: String, url: URL, bookmarkData: Data?) {
        self.title = title
        self.url = url
        self.bookmarkData = bookmarkData
    }
}

@MainActor
public final class AuthorizedRootStore: ObservableObject {
    @Published public private(set) var roots: [AuthorizedRoot]

    private let defaults: UserDefaults
    private let defaultsKey = "Explorer.authorizedRoots"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([AuthorizedRoot].self, from: data) {
            self.roots = decoded.compactMap(Self.resolve)
        } else {
            self.roots = []
        }
    }

    @discardableResult
    public func add(url: URL) -> AuthorizedRoot {
        let bookmarkData = Self.bookmarkData(for: url)
        let root = AuthorizedRoot(title: url.lastPathComponent, url: url, bookmarkData: bookmarkData)

        if !roots.contains(where: { $0.url == root.url }) {
            roots.append(root)
            save()
        }

        return root
    }

    public func remove(_ root: AuthorizedRoot) {
        roots.removeAll { $0.id == root.id }
        save()
    }

    @discardableResult
    public func startAccessing(_ root: AuthorizedRoot) -> Bool {
        root.url.startAccessingSecurityScopedResource()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(roots) else {
            return
        }

        defaults.set(data, forKey: defaultsKey)
    }

    private static func resolve(_ root: AuthorizedRoot) -> AuthorizedRoot? {
        guard let bookmarkData = root.bookmarkData else {
            return root
        }

        var stale = false
        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkResolutionOptions = []
        #endif

        guard let resolvedURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: options,
            bookmarkDataIsStale: &stale
        ) else {
            return root
        }

        return AuthorizedRoot(
            title: resolvedURL.lastPathComponent,
            url: resolvedURL,
            bookmarkData: stale ? Self.bookmarkData(for: resolvedURL) : bookmarkData
        )
    }

    private static func bookmarkData(for url: URL) -> Data? {
        #if os(macOS)
        return try? url.bookmarkData(options: [.withSecurityScope])
        #else
        return try? url.bookmarkData()
        #endif
    }
}
