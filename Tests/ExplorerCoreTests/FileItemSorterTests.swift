import XCTest
@testable import ExplorerCore

final class FileItemSorterTests: XCTestCase {
    func testFiltersByNameAndType() {
        let items = [
            makeItem(name: "Report.pdf", type: "PDF document"),
            makeItem(name: "Photos", kind: .folder, type: "Folder"),
            makeItem(name: "Notes.txt", type: "Plain text")
        ]

        XCTAssertEqual(FileItemSorter.filtered(items, query: "report").map(\.name), ["Report.pdf"])
        XCTAssertEqual(FileItemSorter.filtered(items, query: "folder").map(\.name), ["Photos"])
        XCTAssertEqual(FileItemSorter.filtered(items, query: "").count, 3)
    }

    func testSortsFoldersFirstThenLocalizedName() {
        let items = [
            makeItem(name: "zeta.txt"),
            makeItem(name: "Archive", kind: .folder),
            makeItem(name: "alpha.txt")
        ]

        let sorted = FileItemSorter.sorted(items, using: FileSort(key: .name, direction: .ascending, foldersFirst: true))

        XCTAssertEqual(sorted.map(\.name), ["Archive", "alpha.txt", "zeta.txt"])
    }

    func testSortsSizeDescending() {
        let items = [
            makeItem(name: "small.txt", size: 10),
            makeItem(name: "large.txt", size: 100),
            makeItem(name: "folder", kind: .folder, size: nil)
        ]

        let sorted = FileItemSorter.sorted(items, using: FileSort(key: .size, direction: .descending, foldersFirst: false))

        XCTAssertEqual(sorted.map(\.name), ["large.txt", "small.txt", "folder"])
    }

    private func makeItem(
        name: String,
        kind: FileItemKind = .file,
        size: Int64? = 0,
        type: String? = nil
    ) -> FileItem {
        FileItem(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            name: name,
            kind: kind,
            size: size,
            createdAt: nil,
            modifiedAt: nil,
            localizedTypeDescription: type,
            typeIdentifier: nil,
            isHidden: false
        )
    }
}

