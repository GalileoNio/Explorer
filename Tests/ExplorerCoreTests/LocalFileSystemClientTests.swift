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

    func testListsRealFileSizeAndModificationDate() async throws {
        let fileURL = temporaryDirectory.appendingPathComponent("metadata.txt")
        let modifiedAt = Date(timeIntervalSince1970: 1_700_000_000)
        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: fileURL.path)

        let snapshot = try await client.contentsOfDirectory(at: temporaryDirectory, includeHidden: false)
        let item = try XCTUnwrap(snapshot.items.first { $0.name == "metadata.txt" })

        XCTAssertEqual(item.size, 5)
        XCTAssertEqual(item.modifiedAt?.timeIntervalSince1970 ?? 0, modifiedAt.timeIntervalSince1970, accuracy: 1)
    }

    func testLoadsRealItemDetails() async throws {
        let fileURL = temporaryDirectory.appendingPathComponent("details.txt")
        let modifiedAt = Date(timeIntervalSince1970: 1_710_000_000)
        try "details".write(to: fileURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: fileURL.path)

        let details = try await client.detailsOfItem(at: fileURL)

        XCTAssertEqual(details.name, "details.txt")
        XCTAssertEqual(details.size, 7)
        XCTAssertEqual(details.modifiedAt?.timeIntervalSince1970 ?? 0, modifiedAt.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(details.pathExtension, ".txt")
        XCTAssertEqual(details.location, temporaryDirectory.standardizedFileURL.path)
        XCTAssertTrue(details.isReadable)
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

    func testDuplicateItemsCreatesCopyForEachSource() async throws {
        let firstURL = temporaryDirectory.appendingPathComponent("first.txt")
        let secondURL = temporaryDirectory.appendingPathComponent("second.txt")
        try "one".write(to: firstURL, atomically: true, encoding: .utf8)
        try "two".write(to: secondURL, atomically: true, encoding: .utf8)

        let duplicates = try await client.duplicateItems([firstURL, secondURL])

        XCTAssertEqual(Set(duplicates.map(\.lastPathComponent)), ["first copy.txt", "second copy.txt"])
        XCTAssertTrue(duplicates.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
    }
}
