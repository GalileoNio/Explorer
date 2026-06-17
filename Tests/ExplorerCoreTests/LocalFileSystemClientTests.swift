import XCTest
@testable import ExplorerCore

final class LocalFileSystemClientTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var client: LocalFileSystemClient!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExplorerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        client = LocalFileSystemClient()
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testListsDirectoryContents() async throws {
        let fileURL = temporaryDirectory.appendingPathComponent("sample.txt")
        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)

        let snapshot = try await client.contentsOfDirectory(at: temporaryDirectory, includeHidden: false)

        XCTAssertEqual(snapshot.items.map(\.name), ["sample.txt"])
    }

    func testCreatesRenamesCopiesAndMovesFolder() async throws {
        let folder = try await client.createFolder(named: "Work", in: temporaryDirectory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))

        let renamed = try await client.renameItem(at: folder, to: "Projects")
        XCTAssertEqual(renamed.lastPathComponent, "Projects")

        let copies = try await client.copyItems([renamed], to: temporaryDirectory)
        XCTAssertEqual(copies.first?.lastPathComponent, "Projects copy")

        let destination = temporaryDirectory.appendingPathComponent("Destination")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        let moved = try await client.moveItems(copies, to: destination)

        XCTAssertEqual(moved.first?.deletingLastPathComponent().standardizedFileURL.path, destination.standardizedFileURL.path)
    }

    func testDuplicateUsesCopySuffix() async throws {
        let fileURL = temporaryDirectory.appendingPathComponent("note.txt")
        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)

        let duplicate = try await client.duplicateItem(at: fileURL)

        XCTAssertEqual(duplicate.lastPathComponent, "note copy.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: duplicate.path))
    }
}
