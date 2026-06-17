import Foundation

public enum PlaceCategory: String, Codable, Sendable {
    case primary
    case system
    case authorized
}

public struct Place: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let url: URL
    public let systemImageName: String
    public let category: PlaceCategory

    public init(title: String, url: URL, systemImageName: String, category: PlaceCategory) {
        self.id = url.path
        self.title = title
        self.url = url
        self.systemImageName = systemImageName
        self.category = category
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

        append(.desktopDirectory, title: "Desktop", symbol: "desktopcomputer", to: &places, fileManager: fileManager)
        append(.documentDirectory, title: "Documents", symbol: "doc.text", to: &places, fileManager: fileManager)
        append(.downloadsDirectory, title: "Downloads", symbol: "arrow.down.circle", to: &places, fileManager: fileManager)
        append(.applicationDirectory, title: "Applications", symbol: "app", to: &places, fileManager: fileManager)
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
        to places: inout [Place],
        fileManager: FileManager
    ) {
        guard let url = fileManager.urls(for: directory, in: .userDomainMask).first else {
            return
        }

        places.append(
            Place(title: title, url: url, systemImageName: symbol, category: .primary)
        )
    }
}
