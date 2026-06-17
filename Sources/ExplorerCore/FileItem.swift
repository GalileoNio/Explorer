import Foundation

public enum FileItemKind: String, Codable, CaseIterable, Sendable {
    case folder
    case package
    case application
    case symbolicLink
    case file
    case unknown
}

public struct FileItem: Identifiable, Hashable, Sendable {
    public var id: URL { url }

    public let url: URL
    public let name: String
    public let kind: FileItemKind
    public let size: Int64?
    public let createdAt: Date?
    public let modifiedAt: Date?
    public let localizedTypeDescription: String?
    public let typeIdentifier: String?
    public let isHidden: Bool

    public init(
        url: URL,
        name: String,
        kind: FileItemKind,
        size: Int64?,
        createdAt: Date?,
        modifiedAt: Date?,
        localizedTypeDescription: String?,
        typeIdentifier: String?,
        isHidden: Bool
    ) {
        self.url = url
        self.name = name
        self.kind = kind
        self.size = size
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.localizedTypeDescription = localizedTypeDescription
        self.typeIdentifier = typeIdentifier
        self.isHidden = isHidden
    }

    public var isNavigable: Bool {
        kind == .folder || kind == .package || kind == .application
    }

    public var formattedSize: String {
        guard kind == .file || kind == .symbolicLink || kind == .unknown, let size else {
            return "--"
        }

        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public var displayType: String {
        localizedTypeDescription ?? kind.rawValue.capitalized
    }

    public var systemImageName: String {
        switch kind {
        case .folder:
            return "folder"
        case .package:
            return "shippingbox"
        case .application:
            return "app"
        case .symbolicLink:
            return "arrowshape.turn.up.right"
        case .file, .unknown:
            return Self.symbolName(forExtension: url.pathExtension)
        }
    }

    public static let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .isPackageKey,
        .isApplicationKey,
        .isSymbolicLinkKey,
        .fileSizeKey,
        .totalFileAllocatedSizeKey,
        .creationDateKey,
        .contentModificationDateKey,
        .localizedTypeDescriptionKey,
        .typeIdentifierKey,
        .isHiddenKey
    ]

    public static func make(url: URL) throws -> FileItem {
        let standardizedURL = url.standardizedFileURL
        let values = try standardizedURL.resourceValues(forKeys: resourceKeys)
        let kind = kind(for: values)
        let size = values.fileSize.map(Int64.init) ?? values.totalFileAllocatedSize.map(Int64.init)

        return FileItem(
            url: standardizedURL,
            name: standardizedURL.lastPathComponent.isEmpty ? standardizedURL.path : standardizedURL.lastPathComponent,
            kind: kind,
            size: size,
            createdAt: values.creationDate,
            modifiedAt: values.contentModificationDate,
            localizedTypeDescription: values.localizedTypeDescription,
            typeIdentifier: values.typeIdentifier,
            isHidden: values.isHidden ?? standardizedURL.lastPathComponent.hasPrefix(".")
        )
    }

    public static func fallback(url: URL) -> FileItem {
        let standardizedURL = url.standardizedFileURL
        return FileItem(
            url: standardizedURL,
            name: standardizedURL.lastPathComponent.isEmpty ? standardizedURL.path : standardizedURL.lastPathComponent,
            kind: .unknown,
            size: nil,
            createdAt: nil,
            modifiedAt: nil,
            localizedTypeDescription: nil,
            typeIdentifier: nil,
            isHidden: standardizedURL.lastPathComponent.hasPrefix(".")
        )
    }

    private static func kind(for values: URLResourceValues) -> FileItemKind {
        if values.isSymbolicLink == true {
            return .symbolicLink
        }

        if values.isApplication == true {
            return .application
        }

        if values.isPackage == true {
            return .package
        }

        if values.isDirectory == true {
            return .folder
        }

        return .file
    }

    private static func symbolName(forExtension pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "tiff":
            return "photo"
        case "pdf":
            return "doc.richtext"
        case "txt", "md", "rtf", "log":
            return "doc.text"
        case "swift", "json", "xml", "html", "css", "js", "ts", "py", "rb", "go", "rs", "c", "h", "m":
            return "curlybraces"
        case "zip", "tar", "gz", "7z", "rar", "dmg", "pkg":
            return "archivebox"
        case "mp3", "m4a", "wav", "flac":
            return "music.note"
        case "mov", "mp4", "m4v", "avi", "mkv":
            return "film"
        default:
            return "doc"
        }
    }
}
