import Foundation

public enum PlaceCategory: String, Codable, Sendable {
    case primary
    case system
    case authorized
}

public enum ExplorerVirtualLocation: String, Codable, CaseIterable, Sendable {
    case recents

    public var url: URL {
        switch self {
        case .recents:
            return URL(string: "explorer://recents")!
        }
    }

    public var title: String {
        switch self {
        case .recents:
            return "Recent"
        }
    }

    public var systemImageName: String {
        switch self {
        case .recents:
            return "clock"
        }
    }

    public static func location(for url: URL) -> ExplorerVirtualLocation? {
        Self.allCases.first { $0.url == url }
    }
}

public enum PlaceTarget: Hashable, Sendable {
    case directory(URL)
    case virtual(ExplorerVirtualLocation)

    public var navigationURL: URL {
        switch self {
        case .directory(let url):
            return url.standardizedFileURL
        case .virtual(let location):
            return location.url
        }
    }

    public var fileURL: URL? {
        switch self {
        case .directory(let url):
            return url.standardizedFileURL
        case .virtual:
            return nil
        }
    }
}

public struct Place: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let target: PlaceTarget
    public let systemImageName: String
    public let category: PlaceCategory

    public init(title: String, url: URL, systemImageName: String, category: PlaceCategory) {
        let target = PlaceTarget.directory(url)
        self.id = target.navigationURL.absoluteString
        self.title = title
        self.target = target
        self.systemImageName = systemImageName
        self.category = category
    }

    public init(title: String, target: PlaceTarget, systemImageName: String, category: PlaceCategory) {
        self.id = target.navigationURL.absoluteString
        self.title = title
        self.target = target
        self.systemImageName = systemImageName
        self.category = category
    }

    public var url: URL {
        target.navigationURL
    }
}

public enum ExplorerDefaultRoot {
    public static var url: URL {
        #if os(macOS)
        FileManager.default.homeDirectoryForCurrentUser
        #else
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        #endif
    }
}

public enum DefaultPlaces {
    public static func primaryPlaces(fileManager: FileManager = .default) -> [Place] {
        #if os(macOS)
        var places: [Place] = [
            Place(title: "Home", url: fileManager.homeDirectoryForCurrentUser, systemImageName: "house", category: .primary)
        ]

        places.append(
            Place(
                title: ExplorerVirtualLocation.recents.title,
                target: .virtual(.recents),
                systemImageName: ExplorerVirtualLocation.recents.systemImageName,
                category: .system
            )
        )
        append(.desktopDirectory, title: "Desktop", symbol: "desktopcomputer", to: &places, fileManager: fileManager)
        append(.documentDirectory, title: "Documents", symbol: "doc.text", to: &places, fileManager: fileManager)
        append(.downloadsDirectory, title: "Downloads", symbol: "arrow.down.circle", to: &places, fileManager: fileManager)
        append(.applicationDirectory, title: "Applications", symbol: "square.grid.2x2", to: &places, fileManager: fileManager)
        append(.trashDirectory, title: "Trash", symbol: "trash", category: .system, to: &places, fileManager: fileManager)
        places.append(
            Place(
                title: "Computer",
                url: URL(fileURLWithPath: "/"),
                systemImageName: "internaldrive",
                category: .system
            )
        )
        places.append(
            Place(
                title: "Volumes",
                url: URL(fileURLWithPath: "/Volumes"),
                systemImageName: "externaldrive",
                category: .system
            )
        )
        places.append(contentsOf: removableVolumePlaces(fileManager: fileManager))
        #else
        var places: [Place] = [
            Place(title: "Files", url: ExplorerDefaultRoot.url, systemImageName: "folder", category: .primary)
        ]
        #endif

        return places
    }

    private static func append(
        _ directory: FileManager.SearchPathDirectory,
        title: String,
        symbol: String,
        category: PlaceCategory = .primary,
        to places: inout [Place],
        fileManager: FileManager
    ) {
        guard let url = fileManager.urls(for: directory, in: .userDomainMask).first else {
            return
        }

        places.append(
            Place(title: title, url: url, systemImageName: symbol, category: category)
        )
    }

    #if os(macOS)
    private static func removableVolumePlaces(fileManager: FileManager) -> [Place] {
        let keys: [URLResourceKey] = [
            .volumeLocalizedNameKey,
            .volumeNameKey,
            .volumeIsEjectableKey,
            .volumeIsRemovableKey
        ]
        let mountedVolumes = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? []

        return mountedVolumes.compactMap { volumeURL in
            let values = try? volumeURL.resourceValues(forKeys: Set(keys))
            guard values?.volumeIsEjectable == true || values?.volumeIsRemovable == true else {
                return nil
            }

            let title = values?.volumeLocalizedName
                ?? values?.volumeName
                ?? volumeURL.lastPathComponent

            return Place(
                title: title.isEmpty ? volumeURL.path : title,
                url: volumeURL,
                systemImageName: "externaldrive",
                category: .system
            )
        }
    }
    #endif
}
