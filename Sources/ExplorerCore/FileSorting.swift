import Foundation

public enum FileViewMode: String, Codable, CaseIterable, Sendable {
    case grid
    case list
}

public enum FileSortKey: String, Codable, CaseIterable, Sendable {
    case name
    case kind
    case size
    case modified
}

public enum FileSortDirection: String, Codable, CaseIterable, Sendable {
    case ascending
    case descending
}

public struct FileSort: Codable, Equatable, Sendable {
    public var key: FileSortKey
    public var direction: FileSortDirection
    public var foldersFirst: Bool

    public init(
        key: FileSortKey = .name,
        direction: FileSortDirection = .ascending,
        foldersFirst: Bool = true
    ) {
        self.key = key
        self.direction = direction
        self.foldersFirst = foldersFirst
    }
}

public enum FileItemSorter {
    public static func filtered(_ items: [FileItem], query: String) -> [FileItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return items
        }

        return items.filter { item in
            item.name.localizedCaseInsensitiveContains(trimmedQuery)
                || item.displayType.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    public static func sorted(_ items: [FileItem], using sort: FileSort) -> [FileItem] {
        items.sorted { left, right in
            if sort.foldersFirst, left.isNavigable != right.isNavigable {
                return left.isNavigable && !right.isNavigable
            }

            let result: ComparisonResult
            switch sort.key {
            case .name:
                result = left.name.localizedStandardCompare(right.name)
            case .kind:
                result = left.displayType.localizedStandardCompare(right.displayType)
            case .size:
                result = compare(left.size ?? -1, right.size ?? -1)
            case .modified:
                result = compare(left.modifiedAt ?? .distantPast, right.modifiedAt ?? .distantPast)
            }

            if result == .orderedSame {
                return left.name.localizedStandardCompare(right.name) == .orderedAscending
            }

            return sort.direction == .ascending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    private static func compare<T: Comparable>(_ left: T, _ right: T) -> ComparisonResult {
        if left < right {
            return .orderedAscending
        }

        if left > right {
            return .orderedDescending
        }

        return .orderedSame
    }
}

