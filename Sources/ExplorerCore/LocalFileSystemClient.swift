import Foundation

public struct LocalFileSystemClient: FileSystemClient, @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func contentsOfDirectory(at url: URL, includeHidden: Bool = false) async throws -> DirectorySnapshot {
        let directoryURL = url.standardizedFileURL
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) else {
            throw ExplorerError.notFound(directoryURL)
        }

        guard isDirectory.boolValue else {
            throw ExplorerError.notDirectory(directoryURL)
        }

        do {
            var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
            if !includeHidden {
                options.insert(.skipsHiddenFiles)
            }

            let urls = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: Array(FileItem.resourceKeys),
                options: options
            )

            let items = urls.map { url in
                (try? FileItem.make(url: url)) ?? FileItem.fallback(url: url)
            }

            return DirectorySnapshot(url: directoryURL, items: items)
        } catch {
            throw map(error, for: directoryURL)
        }
    }

    public func createFolder(named name: String, in directory: URL) async throws -> URL {
        let trimmedName = normalizedName(name)
        let destination = availableURL(forName: trimmedName, in: directory, preservingExtension: false)

        do {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: false)
            return destination
        } catch {
            throw map(error, for: destination)
        }
    }

    public func renameItem(at url: URL, to newName: String) async throws -> URL {
        let trimmedName = normalizedName(newName)
        let destination = url.deletingLastPathComponent().appendingPathComponent(trimmedName)

        guard destination != url else {
            return url
        }

        guard !fileManager.fileExists(atPath: destination.path) else {
            throw ExplorerError.itemExists(destination)
        }

        do {
            try fileManager.moveItem(at: url, to: destination)
            return destination
        } catch {
            throw map(error, for: destination)
        }
    }

    public func copyItems(_ urls: [URL], to destinationDirectory: URL) async throws -> [URL] {
        try urls.map { source in
            let destination = availableURL(for: source, in: destinationDirectory)
            do {
                try fileManager.copyItem(at: source, to: destination)
                return destination
            } catch {
                throw map(error, for: destination)
            }
        }
    }

    public func moveItems(_ urls: [URL], to destinationDirectory: URL) async throws -> [URL] {
        try urls.map { source in
            let destination = availableURL(for: source, in: destinationDirectory)
            do {
                try fileManager.moveItem(at: source, to: destination)
                return destination
            } catch {
                throw map(error, for: destination)
            }
        }
    }

    public func duplicateItem(at url: URL) async throws -> URL {
        let parent = url.deletingLastPathComponent()
        return try await copyItems([url], to: parent).first ?? url
    }

    public func trashItems(_ urls: [URL]) async throws {
        for url in urls {
            do {
                #if os(macOS)
                var resultingURL: NSURL?
                try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
                #else
                try fileManager.removeItem(at: url)
                #endif
            } catch {
                throw map(error, for: url)
            }
        }
    }

    private func normalizedName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Folder" : trimmed
    }

    private func availableURL(for source: URL, in directory: URL) -> URL {
        availableURL(forName: source.lastPathComponent, in: directory, preservingExtension: true)
    }

    private func availableURL(forName name: String, in directory: URL, preservingExtension: Bool) -> URL {
        let initialURL = directory.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: initialURL.path) else {
            return initialURL
        }

        let nsName = name as NSString
        let baseName: String
        let pathExtension: String

        if preservingExtension, !nsName.pathExtension.isEmpty {
            baseName = nsName.deletingPathExtension
            pathExtension = nsName.pathExtension
        } else {
            baseName = name
            pathExtension = ""
        }

        var index = 1
        while true {
            let suffix = index == 1 ? " copy" : " copy \(index)"
            let candidateName = pathExtension.isEmpty ? "\(baseName)\(suffix)" : "\(baseName)\(suffix).\(pathExtension)"
            let candidateURL = directory.appendingPathComponent(candidateName)

            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }

            index += 1
        }
    }

    private func map(_ error: Error, for url: URL) -> ExplorerError {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileNoSuchFileError:
                return .notFound(url)
            case NSFileReadNoPermissionError, NSFileWriteNoPermissionError:
                return .permissionDenied(url)
            case NSFileWriteFileExistsError:
                return .itemExists(url)
            default:
                break
            }
        }

        return .operationFailed(nsError.localizedDescription)
    }
}
