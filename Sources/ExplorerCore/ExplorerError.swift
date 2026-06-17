import Foundation

public enum ExplorerError: LocalizedError, Equatable, Sendable {
    case notFound(URL)
    case notDirectory(URL)
    case permissionDenied(URL)
    case itemExists(URL)
    case unsupported(String)
    case operationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let url):
            return "The item could not be found: \(url.path)"
        case .notDirectory(let url):
            return "This item is not a folder: \(url.path)"
        case .permissionDenied(let url):
            return "Explorer does not have permission to access \(url.path). On macOS, grant Full Disk Access in System Settings if this is a protected location."
        case .itemExists(let url):
            return "An item already exists at \(url.path)."
        case .unsupported(let message):
            return message
        case .operationFailed(let message):
            return message
        }
    }
}

