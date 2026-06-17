import Foundation

public protocol FileSystemClient: Sendable {
    func contentsOfDirectory(at url: URL, includeHidden: Bool) async throws -> DirectorySnapshot
    func detailsOfItem(at url: URL) async throws -> FileItemDetails
    func createFolder(named name: String, in directory: URL) async throws -> URL
    func renameItem(at url: URL, to newName: String) async throws -> URL
    func copyItems(_ urls: [URL], to destinationDirectory: URL) async throws -> [URL]
    func moveItems(_ urls: [URL], to destinationDirectory: URL) async throws -> [URL]
    func duplicateItem(at url: URL) async throws -> URL
    func duplicateItems(_ urls: [URL]) async throws -> [URL]
    func trashItems(_ urls: [URL]) async throws
}
