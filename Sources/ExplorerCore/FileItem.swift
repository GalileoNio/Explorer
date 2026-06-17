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
        .contentAccessDateKey,
        .isDirectoryKey,
        .isPackageKey,
        .isApplicationKey,
        .isSymbolicLinkKey,
        .fileSizeKey,
        .totalFileSizeKey,
        .fileAllocatedSizeKey,
        .totalFileAllocatedSizeKey,
        .creationDateKey,
        .contentModificationDateKey,
        .localizedTypeDescriptionKey,
        .typeIdentifierKey,
        .isHiddenKey
    ]

    public static func make(url: URL) throws -> FileItem {
        let standardizedURL = url.standardizedFileURL
        let values = try? standardizedURL.resourceValues(forKeys: resourceKeys)
        let attributes = try? FileManager.default.attributesOfItem(atPath: standardizedURL.path)

        guard values != nil || attributes != nil else {
            _ = try standardizedURL.resourceValues(forKeys: resourceKeys)
            return fallback(url: standardizedURL)
        }

        let kind = kind(for: values, attributes: attributes)
        let size = logicalSize(for: kind, values: values, attributes: attributes)

        return FileItem(
            url: standardizedURL,
            name: standardizedURL.lastPathComponent.isEmpty ? standardizedURL.path : standardizedURL.lastPathComponent,
            kind: kind,
            size: size,
            createdAt: values?.creationDate ?? attributes?[.creationDate] as? Date,
            modifiedAt: values?.contentModificationDate ?? attributes?[.modificationDate] as? Date,
            localizedTypeDescription: values?.localizedTypeDescription,
            typeIdentifier: values?.typeIdentifier,
            isHidden: values?.isHidden ?? standardizedURL.lastPathComponent.hasPrefix(".")
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

    private static func kind(
        for values: URLResourceValues?,
        attributes: [FileAttributeKey: Any]? = nil
    ) -> FileItemKind {
        if values?.isSymbolicLink == true {
            return .symbolicLink
        }

        if values?.isApplication == true {
            return .application
        }

        if values?.isPackage == true {
            return .package
        }

        if values?.isDirectory == true {
            return .folder
        }

        if let fileType = attributes?[.type] as? FileAttributeType {
            switch fileType {
            case .typeSymbolicLink:
                return .symbolicLink
            case .typeDirectory:
                return .folder
            case .typeRegular:
                return .file
            default:
                return .unknown
            }
        }

        return .file
    }

    private static func logicalSize(
        for kind: FileItemKind,
        values: URLResourceValues?,
        attributes: [FileAttributeKey: Any]?
    ) -> Int64? {
        guard kind == .file || kind == .symbolicLink || kind == .unknown else {
            return nil
        }

        if let fileSize = values?.fileSize {
            return Int64(fileSize)
        }

        if let totalFileSize = values?.totalFileSize {
            return Int64(totalFileSize)
        }

        if let attributeSize = attributes?[.size] as? NSNumber {
            return attributeSize.int64Value
        }

        return nil
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

public struct FileItemDetails: Identifiable, Hashable, Sendable {
    public var id: URL { url }

    public let url: URL
    public let name: String
    public let kind: FileItemKind
    public let size: Int64?
    public let allocatedSize: Int64?
    public let createdAt: Date?
    public let modifiedAt: Date?
    public let accessedAt: Date?
    public let localizedTypeDescription: String?
    public let typeIdentifier: String?
    public let isHidden: Bool
    public let isReadable: Bool
    public let isWritable: Bool
    public let isExecutable: Bool
    public let ownerAccountName: String?
    public let groupOwnerAccountName: String?
    public let posixPermissions: Int?

    public init(
        url: URL,
        name: String,
        kind: FileItemKind,
        size: Int64?,
        allocatedSize: Int64?,
        createdAt: Date?,
        modifiedAt: Date?,
        accessedAt: Date?,
        localizedTypeDescription: String?,
        typeIdentifier: String?,
        isHidden: Bool,
        isReadable: Bool,
        isWritable: Bool,
        isExecutable: Bool,
        ownerAccountName: String?,
        groupOwnerAccountName: String?,
        posixPermissions: Int?
    ) {
        self.url = url
        self.name = name
        self.kind = kind
        self.size = size
        self.allocatedSize = allocatedSize
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.accessedAt = accessedAt
        self.localizedTypeDescription = localizedTypeDescription
        self.typeIdentifier = typeIdentifier
        self.isHidden = isHidden
        self.isReadable = isReadable
        self.isWritable = isWritable
        self.isExecutable = isExecutable
        self.ownerAccountName = ownerAccountName
        self.groupOwnerAccountName = groupOwnerAccountName
        self.posixPermissions = posixPermissions
    }

    public var formattedSize: String {
        guard let size else {
            return "--"
        }

        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public var formattedAllocatedSize: String {
        guard let allocatedSize else {
            return "--"
        }

        return ByteCountFormatter.string(fromByteCount: allocatedSize, countStyle: .file)
    }

    public var displayType: String {
        localizedTypeDescription ?? kind.rawValue.capitalized
    }

    public var location: String {
        url.deletingLastPathComponent().path
    }

    public var pathExtension: String {
        let value = url.pathExtension
        return value.isEmpty ? "--" : ".\(value.lowercased())"
    }

    public var formattedPOSIXPermissions: String {
        guard let posixPermissions else {
            return "--"
        }

        return String(format: "%03o", posixPermissions)
    }

    public static func make(url: URL, fileManager: FileManager = .default) throws -> FileItemDetails {
        let standardizedURL = url.standardizedFileURL
        let values = try? standardizedURL.resourceValues(forKeys: FileItem.resourceKeys)
        let attributes = try? fileManager.attributesOfItem(atPath: standardizedURL.path)

        guard values != nil || attributes != nil else {
            _ = try fileManager.attributesOfItem(atPath: standardizedURL.path)
            throw ExplorerError.notFound(standardizedURL)
        }

        let item = (try? FileItem.make(url: standardizedURL)) ?? FileItem.fallback(url: standardizedURL)

        return FileItemDetails(
            url: standardizedURL,
            name: item.name,
            kind: item.kind,
            size: item.size,
            allocatedSize: allocatedSize(for: item.kind, values: values, attributes: attributes),
            createdAt: item.createdAt,
            modifiedAt: item.modifiedAt,
            accessedAt: values?.contentAccessDate,
            localizedTypeDescription: item.localizedTypeDescription,
            typeIdentifier: item.typeIdentifier,
            isHidden: item.isHidden,
            isReadable: fileManager.isReadableFile(atPath: standardizedURL.path),
            isWritable: fileManager.isWritableFile(atPath: standardizedURL.path),
            isExecutable: fileManager.isExecutableFile(atPath: standardizedURL.path),
            ownerAccountName: attributes?[.ownerAccountName] as? String,
            groupOwnerAccountName: attributes?[.groupOwnerAccountName] as? String,
            posixPermissions: (attributes?[.posixPermissions] as? NSNumber)?.intValue
        )
    }

    private static func allocatedSize(
        for kind: FileItemKind,
        values: URLResourceValues?,
        attributes: [FileAttributeKey: Any]?
    ) -> Int64? {
        guard kind == .file || kind == .symbolicLink || kind == .unknown else {
            return nil
        }

        if let allocatedSize = values?.fileAllocatedSize {
            return Int64(allocatedSize)
        }

        if let totalAllocatedSize = values?.totalFileAllocatedSize {
            return Int64(totalAllocatedSize)
        }

        return (attributes?[.size] as? NSNumber)?.int64Value
    }
}
