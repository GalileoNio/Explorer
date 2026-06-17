import Foundation

public struct DirectorySnapshot: Equatable, Sendable {
    public let url: URL
    public let items: [FileItem]
    public let loadedAt: Date

    public init(url: URL, items: [FileItem], loadedAt: Date = Date()) {
        self.url = url
        self.items = items
        self.loadedAt = loadedAt
    }
}

