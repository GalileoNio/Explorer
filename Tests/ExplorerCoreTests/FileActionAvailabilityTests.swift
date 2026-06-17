import XCTest
@testable import ExplorerCore

final class FileActionAvailabilityTests: XCTestCase {
    func testClickedSelectedItemActsOnWholeSelection() {
        let first = makeItem(name: "first.txt")
        let second = makeItem(name: "second.txt")
        let context = FileActionContext(
            currentDirectory: URL(fileURLWithPath: "/tmp"),
            clickedItem: first,
            selectedItems: [first, second]
        )

        XCTAssertEqual(context.actedItems.map(\.name), ["first.txt", "second.txt"])
    }

    func testClickedUnselectedItemActsOnlyOnClickedItem() {
        let first = makeItem(name: "first.txt")
        let second = makeItem(name: "second.txt")
        let context = FileActionContext(
            currentDirectory: URL(fileURLWithPath: "/tmp"),
            clickedItem: second,
            selectedItems: [first]
        )

        XCTAssertEqual(context.actedItems.map(\.name), ["second.txt"])
    }

    func testRenameRequiresSingleItemAndWritableDirectory() {
        let item = makeItem(name: "note.txt")
        let writable = FileActionAvailability(context: FileActionContext(
            currentDirectory: URL(fileURLWithPath: "/tmp"),
            clickedItem: item,
            selectedItems: [item],
            isCurrentDirectoryWritable: true
        ))
        let readOnly = FileActionAvailability(context: FileActionContext(
            currentDirectory: URL(fileURLWithPath: "/tmp"),
            clickedItem: item,
            selectedItems: [item],
            isCurrentDirectoryWritable: false
        ))

        XCTAssertTrue(writable.canRename)
        XCTAssertFalse(readOnly.canRename)
    }

    func testPasteUsesAppClipboardBeforeSystemPasteboard() {
        let appURL = URL(fileURLWithPath: "/tmp/app.txt")
        let systemURL = URL(fileURLWithPath: "/tmp/system.txt")
        let context = FileActionContext(
            currentDirectory: URL(fileURLWithPath: "/tmp"),
            pasteboardURLs: [systemURL],
            clipboardOperation: ClipboardOperation(kind: .move, urls: [appURL])
        )

        XCTAssertEqual(context.pasteURLs, [appURL])
        XCTAssertEqual(context.resolvedPasteOperation, .move)
    }

    func testFolderTargetEnablesPasteIntoTarget() {
        let folder = makeItem(name: "Folder", kind: .folder)
        let context = FileActionContext(
            currentDirectory: URL(fileURLWithPath: "/tmp"),
            clickedItem: folder,
            pasteboardURLs: [URL(fileURLWithPath: "/tmp/source.txt")]
        )

        XCTAssertTrue(FileActionAvailability(context: context).canPasteIntoTarget)
        XCTAssertEqual(context.pasteDestination.path, folder.url.path)
    }

    private func makeItem(name: String, kind: FileItemKind = .file) -> FileItem {
        FileItem(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            name: name,
            kind: kind,
            size: kind == .folder ? nil : 0,
            createdAt: nil,
            modifiedAt: nil,
            localizedTypeDescription: nil,
            typeIdentifier: nil,
            isHidden: false
        )
    }
}
