import Combine
import Foundation

public enum AuthorizedRootKind: String, Codable, Sendable {
    case folder
    case file

    public var systemImageName: String {
        switch self {
        case .folder:
            return "folder.badge.person.crop"
        case .file:
            return "doc.badge.plus"
        }
    }
}

public struct AuthorizedRoot: Identifiable, Hashable, Codable, Sendable {
    public let title: String
    public let url: URL
    public let bookmarkData: Data?
    public let kind: AuthorizedRootKind

    public var id: String { url.path }
    public var isDirectory: Bool { kind == .folder }

    public init(
        title: String,
        url: URL,
        bookmarkData: Data?,
        kind: AuthorizedRootKind = .folder
    ) {
        self.title = title
        self.url = url.standardizedFileURL
        self.bookmarkData = bookmarkData
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case url
        case bookmarkData
        case kind
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decode(String.self, forKey: .title)
        self.url = try container.decode(URL.self, forKey: .url).standardizedFileURL
        self.bookmarkData = try container.decodeIfPresent(Data.self, forKey: .bookmarkData)
        self.kind = try container.decodeIfPresent(AuthorizedRootKind.self, forKey: .kind) ?? .folder
    }
}

@MainActor
public final class AuthorizedRootStore: ObservableObject {
    @Published public private(set) var roots: [AuthorizedRoot]

    private let defaults: UserDefaults
    private let defaultsKey = "Explorer.authorizedRoots"
    private var activeScopedRootIDs: Set<String> = []

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([AuthorizedRoot].self, from: data) {
            let resolvedRoots = decoded.map(Self.resolve)
            self.roots = resolvedRoots.map(\.root)

            if resolvedRoots.contains(where: \.shouldSave) {
                save()
            }
        } else {
            self.roots = []
        }
    }

    @discardableResult
    public func add(url: URL) -> AuthorizedRoot {
        let standardizedURL = url.standardizedFileURL
        let didStartAccessing = standardizedURL.startAccessingSecurityScopedResource()
        let root = AuthorizedRoot(
            title: Self.displayTitle(for: standardizedURL),
            url: standardizedURL,
            bookmarkData: Self.bookmarkData(for: standardizedURL),
            kind: Self.kind(for: standardizedURL)
        )

        if let index = roots.firstIndex(where: { $0.url == root.url }) {
            roots[index] = root
            save()
        } else {
            roots.append(root)
            save()
        }

        if didStartAccessing {
            activeScopedRootIDs.insert(root.id)
        }

        return root
    }

    public func remove(_ root: AuthorizedRoot) {
        stopAccessing(root)
        roots.removeAll { $0.id == root.id }
        save()
    }

    @discardableResult
    public func startAccessing(_ root: AuthorizedRoot) -> Bool {
        guard root.bookmarkData != nil else {
            return true
        }

        guard !activeScopedRootIDs.contains(root.id) else {
            return true
        }

        let didStartAccessing = root.url.startAccessingSecurityScopedResource()
        if didStartAccessing {
            activeScopedRootIDs.insert(root.id)
        }

        return didStartAccessing
    }

    public func stopAccessing(_ root: AuthorizedRoot) {
        guard activeScopedRootIDs.remove(root.id) != nil else {
            return
        }

        root.url.stopAccessingSecurityScopedResource()
    }

    public func root(containing url: URL) -> AuthorizedRoot? {
        let standardizedURL = url.standardizedFileURL
        return roots
            .filter { root in
                switch root.kind {
                case .folder:
                    return Self.folder(root.url, contains: standardizedURL)
                case .file:
                    return root.url == standardizedURL
                }
            }
            .max { left, right in
                left.url.path.count < right.url.path.count
            }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(roots) else {
            return
        }

        defaults.set(data, forKey: defaultsKey)
    }

    private static func resolve(_ root: AuthorizedRoot) -> (root: AuthorizedRoot, shouldSave: Bool) {
        guard let bookmarkData = root.bookmarkData else {
            return (root, false)
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
            return (root, false)
        }

        let resolvedRoot = AuthorizedRoot(
            title: Self.displayTitle(for: resolvedURL),
            url: resolvedURL.standardizedFileURL,
            bookmarkData: stale ? Self.bookmarkData(for: resolvedURL) : bookmarkData,
            kind: root.kind
        )
        return (resolvedRoot, stale || resolvedRoot.url != root.url || resolvedRoot.title != root.title)
    }

    private static func bookmarkData(for url: URL) -> Data? {
        #if os(macOS)
        return try? url.bookmarkData(options: [.withSecurityScope])
        #else
        return try? url.bookmarkData()
        #endif
    }

    private static func displayTitle(for url: URL) -> String {
        let lastPathComponent = url.lastPathComponent
        return lastPathComponent.isEmpty ? url.path : lastPathComponent
    }

    private static func kind(for url: URL) -> AuthorizedRootKind {
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
            return .folder
        }

        return url.hasDirectoryPath ? .folder : .file
    }

    private static func folder(_ folderURL: URL, contains url: URL) -> Bool {
        let folderPath = folderURL.standardizedFileURL.path
        let path = url.standardizedFileURL.path

        return path == folderPath || path.hasPrefix(folderPath.appendingPathSeparator)
    }
}

private extension String {
    var appendingPathSeparator: String {
        hasSuffix("/") ? self : self + "/"
    }
}
