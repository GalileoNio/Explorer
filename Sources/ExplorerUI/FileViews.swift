import ExplorerCore
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct FileGridView: View {
    let items: [FileItem]
    let selectedURLs: Set<URL>
    let iconSize: CGFloat
    let controller: ExplorerController
    let onRename: (FileItem) -> Void
    let onDetails: (FileItem) -> Void
    let onTransfer: (TransferRequest) -> Void

    private let selectionCoordinateSpace = "FileGridSelection"

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: tileWidth, maximum: tileWidth + 28), spacing: 8)]
    }

    private var tileWidth: CGFloat {
        max(112, min(iconSize * 2.25, 176))
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(items) { item in
                    FileTile(
                        item: item,
                        isSelected: selectedURLs.contains(item.url),
                        iconSize: iconSize,
                        controller: controller,
                        onRename: onRename,
                        onDetails: onDetails,
                        onTransfer: onTransfer
                    )
                    .background(FileItemFrameReader(url: item.url, coordinateSpaceName: selectionCoordinateSpace))
                }
            }
            .padding(10)
        }
        .fileDragSelection(coordinateSpaceName: selectionCoordinateSpace) { selectedURLs in
            controller.setSelectedURLs(selectedURLs)
        }
    }
}

struct FileTile: View {
    let item: FileItem
    let isSelected: Bool
    let iconSize: CGFloat
    let controller: ExplorerController
    let onRename: (FileItem) -> Void
    let onDetails: (FileItem) -> Void
    let onTransfer: (TransferRequest) -> Void

    var body: some View {
        VStack(spacing: 6) {
            FileIconView(item: item, size: iconSize)
            Text(item.name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .top)
        }
        .padding(6)
        .frame(width: tileWidth, height: tileHeight)
        .background(selectionBackground)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            controller.select(item)
        }
        .onTapGesture(count: 2) {
            openOrNavigate(item)
        }
        .contextMenu {
            FileActionMenu(
                item: item,
                selectedURLs: controller.state.selectedURLs,
                controller: controller,
                onRename: onRename,
                onDetails: onDetails,
                onTransfer: onTransfer
            )
        }
        .onDrag {
            NSItemProvider(object: item.url as NSURL)
        }
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            guard item.isNavigable else {
                return false
            }

            return handleDrop(providers, destination: item.url)
        }
    }

    private var selectionBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
            )
    }

    private var tileWidth: CGFloat {
        max(112, min(iconSize * 2.25, 176))
    }

    private var tileHeight: CGFloat {
        max(104, iconSize * 1.25 + 50)
    }

    private func openOrNavigate(_ item: FileItem) {
        if item.isNavigable {
            controller.navigate(to: item.url)
        } else {
            PlatformFileServices.open(item.url)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider], destination: URL) -> Bool {
        let matchingProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }

        guard !matchingProviders.isEmpty else {
            return false
        }

        for provider in matchingProviders {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let error {
                    Task { @MainActor in
                        controller.present(error)
                    }
                    return
                }

                let droppedURL: URL?
                if let url = item as? URL {
                    droppedURL = url
                } else if let data = item as? Data {
                    droppedURL = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    droppedURL = nil
                }

                if let droppedURL {
                    Task { @MainActor in
                        controller.copyItems([droppedURL], to: destination)
                    }
                }
            }
        }

        return true
    }
}

struct FileListView: View {
    let items: [FileItem]
    let selectedURLs: Set<URL>
    let iconSize: CGFloat
    let controller: ExplorerController
    let onRename: (FileItem) -> Void
    let onDetails: (FileItem) -> Void
    let onTransfer: (TransferRequest) -> Void

    private let selectionCoordinateSpace = "FileListSelection"

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(items) { item in
                        FileListRow(
                            item: item,
                            isSelected: selectedURLs.contains(item.url),
                            iconSize: listIconSize,
                            controller: controller,
                            onRename: onRename,
                            onDetails: onDetails,
                            onTransfer: onTransfer
                        )
                        .background(FileItemFrameReader(url: item.url, coordinateSpaceName: selectionCoordinateSpace))
                    }
                } header: {
                    FileListHeader()
                }
            }
            .frame(minWidth: FileListColumns.totalWidth, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .fileDragSelection(coordinateSpaceName: selectionCoordinateSpace) { selectedURLs in
            controller.setSelectedURLs(selectedURLs)
        }
    }

    private var listIconSize: CGFloat {
        min(max(iconSize * 0.42, 16), 26)
    }
}

private enum FileListColumns {
    static let name: CGFloat = 300
    static let modified: CGFloat = 138
    static let created: CGFloat = 138
    static let size: CGFloat = 88
    static let kind: CGFloat = 154
    static let fileExtension: CGFloat = 78
    static let totalWidth = name + modified + created + size + kind + fileExtension + 12 * 5 + 20
}

struct FileListHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("Name")
                .frame(width: FileListColumns.name, alignment: .leading)
            Text("Modified")
                .frame(width: FileListColumns.modified, alignment: .leading)
            Text("Created")
                .frame(width: FileListColumns.created, alignment: .leading)
            Text("Size")
                .frame(width: FileListColumns.size, alignment: .trailing)
            Text("Kind")
                .frame(width: FileListColumns.kind, alignment: .leading)
            Text("Extension")
                .frame(width: FileListColumns.fileExtension, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.regularMaterial)
    }
}

struct FileListRow: View {
    let item: FileItem
    let isSelected: Bool
    let iconSize: CGFloat
    let controller: ExplorerController
    let onRename: (FileItem) -> Void
    let onDetails: (FileItem) -> Void
    let onTransfer: (TransferRequest) -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                FileIconView(item: item, size: iconSize)
                Text(item.name)
                    .lineLimit(1)
                if item.isHidden {
                    Image(systemName: "eye.slash")
                        .imageScale(.small)
                        .foregroundStyle(.tertiary)
                        .help("Hidden")
                }
                if item.kind == .symbolicLink {
                    Image(systemName: "arrowshape.turn.up.right")
                        .imageScale(.small)
                        .foregroundStyle(.tertiary)
                        .help("Symbolic Link")
                }
            }
            .frame(width: FileListColumns.name, alignment: .leading)

            Text(Self.dateText(item.modifiedAt))
                .lineLimit(1)
                .frame(width: FileListColumns.modified, alignment: .leading)

            Text(Self.dateText(item.createdAt))
                .lineLimit(1)
                .frame(width: FileListColumns.created, alignment: .leading)

            Text(item.formattedSize)
                .lineLimit(1)
                .frame(width: FileListColumns.size, alignment: .trailing)

            Text(item.displayType)
                .lineLimit(1)
                .frame(width: FileListColumns.kind, alignment: .leading)

            Text(extensionText)
                .lineLimit(1)
                .frame(width: FileListColumns.fileExtension, alignment: .leading)
        }
        .font(.subheadline)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            controller.select(item)
        }
        .onTapGesture(count: 2) {
            openOrNavigate(item)
        }
        .contextMenu {
            FileActionMenu(
                item: item,
                selectedURLs: controller.state.selectedURLs,
                controller: controller,
                onRename: onRename,
                onDetails: onDetails,
                onTransfer: onTransfer
            )
        }
        .onDrag {
            NSItemProvider(object: item.url as NSURL)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private static func dateText(_ date: Date?) -> String {
        date.map(Self.dateFormatter.string(from:)) ?? "--"
    }

    private var extensionText: String {
        let pathExtension = item.url.pathExtension
        return pathExtension.isEmpty ? "--" : ".\(pathExtension.lowercased())"
    }

    private func openOrNavigate(_ item: FileItem) {
        if item.isNavigable {
            controller.navigate(to: item.url)
        } else {
            PlatformFileServices.open(item.url)
        }
    }
}

struct FileIconView: View {
    let item: FileItem
    let size: CGFloat

    var body: some View {
        platformIcon
            .frame(width: size * 1.25, height: size * 1.25)
    }

    @ViewBuilder
    private var platformIcon: some View {
        #if os(macOS)
        Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
        #elseif os(iOS)
        if let icon = UIDocumentInteractionController(url: item.url).icons.last {
            Image(uiImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            fallbackIcon
        }
        #else
        fallbackIcon
        #endif
    }

    private var fallbackIcon: some View {
        Image(systemName: item.systemImageName)
            .font(.system(size: size, weight: .regular))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(iconColor)
    }

    private var iconColor: Color {
        switch item.kind {
        case .folder:
            return .accentColor
        case .application:
            return .purple
        case .package:
            return .orange
        case .symbolicLink:
            return .teal
        case .file, .unknown:
            return .secondary
        }
    }
}

private struct FileItemFrameReader: View {
    let url: URL
    let coordinateSpaceName: String

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: FileFramePreferenceKey.self,
                value: [url: proxy.frame(in: .named(coordinateSpaceName))]
            )
        }
    }
}

private struct FileFramePreferenceKey: PreferenceKey {
    static let defaultValue: [URL: CGRect] = [:]

    static func reduce(value: inout [URL: CGRect], nextValue: () -> [URL: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

private extension View {
    @ViewBuilder
    func fileDragSelection(coordinateSpaceName: String, onSelect: @escaping (Set<URL>) -> Void) -> some View {
        #if os(macOS)
        modifier(FileDragSelectionSurface(coordinateSpaceName: coordinateSpaceName, onSelect: onSelect))
        #else
        self
        #endif
    }
}

private struct FileDragSelectionSurface: ViewModifier {
    let coordinateSpaceName: String
    let onSelect: (Set<URL>) -> Void

    @State private var itemFrames: [URL: CGRect] = [:]
    @State private var selectionStart: CGPoint?
    @State private var selectionRect: CGRect?

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: coordinateSpaceName)
            .onPreferenceChange(FileFramePreferenceKey.self) { frames in
                itemFrames = frames
            }
            .overlay(alignment: .topLeading) {
                if let selectionRect {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.accentColor.opacity(0.55), lineWidth: 1)
                        )
                        .frame(width: max(selectionRect.width, 1), height: max(selectionRect.height, 1))
                        .offset(x: selectionRect.minX, y: selectionRect.minY)
                        .allowsHitTesting(false)
                }
            }
            .simultaneousGesture(selectionGesture)
    }

    private var selectionGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(coordinateSpaceName))
            .onChanged { value in
                updateSelection(with: value)
            }
            .onEnded { _ in
                selectionStart = nil
                selectionRect = nil
            }
    }

    private func updateSelection(with value: DragGesture.Value) {
        if selectionStart == nil {
            guard canBeginSelection(at: value.startLocation) else {
                return
            }
            selectionStart = value.startLocation
        }

        guard let selectionStart else {
            return
        }

        let rect = CGRect(
            x: min(selectionStart.x, value.location.x),
            y: min(selectionStart.y, value.location.y),
            width: abs(value.location.x - selectionStart.x),
            height: abs(value.location.y - selectionStart.y)
        )
        selectionRect = rect

        let selectedURLs = Set(
            itemFrames
                .filter { _, frame in rect.intersects(frame) }
                .map { url, _ in url }
        )
        onSelect(selectedURLs)
    }

    private func canBeginSelection(at location: CGPoint) -> Bool {
        !itemFrames.values.contains { frame in
            frame.insetBy(dx: -4, dy: -4).contains(location)
        }
    }
}

struct FileInfoSheet: View {
    let item: FileItem
    let controller: ExplorerController

    @Environment(\.dismiss) private var dismiss
    @State private var details: FileItemDetails?
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading Info")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let details {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            header(details)

                            DetailSection("General") {
                                DetailRow("Kind", details.displayType)
                                DetailRow("Size", details.formattedSize)
                                DetailRow("Allocated", details.formattedAllocatedSize)
                                DetailRow("Extension", details.pathExtension)
                                DetailRow("Location", details.location)
                                DetailRow("Path", details.url.path)
                                if let typeIdentifier = details.typeIdentifier {
                                    DetailRow("Type Identifier", typeIdentifier)
                                }
                            }

                            DetailSection("Dates") {
                                DetailRow("Created", Self.dateText(details.createdAt))
                                DetailRow("Modified", Self.dateText(details.modifiedAt))
                                DetailRow("Last Opened", Self.dateText(details.accessedAt))
                            }

                            DetailSection("Access") {
                                DetailRow("Readable", Self.booleanText(details.isReadable))
                                DetailRow("Writable", Self.booleanText(details.isWritable))
                                DetailRow("Executable", Self.booleanText(details.isExecutable))
                                DetailRow("Hidden", Self.booleanText(details.isHidden))
                                DetailRow("Owner", details.ownerAccountName ?? "--")
                                DetailRow("Group", details.groupOwnerAccountName ?? "--")
                                DetailRow("POSIX", details.formattedPOSIXPermissions)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ContentUnavailableView(
                        "Unable to Load Info",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage ?? "Explorer could not read this item.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Get Info")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, idealWidth: 520, minHeight: 560)
        #endif
        .task(id: item.url) {
            await loadDetails()
        }
    }

    private func header(_ details: FileItemDetails) -> some View {
        HStack(spacing: 14) {
            FileIconView(item: item, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(details.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .textSelection(.enabled)

                Text(details.displayType)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @MainActor
    private func loadDetails() async {
        isLoading = true
        errorMessage = nil

        do {
            details = try await controller.details(for: item)
        } catch {
            details = nil
            if let explorerError = error as? ExplorerError {
                errorMessage = explorerError.errorDescription
            } else {
                errorMessage = (error as NSError).localizedDescription
            }
        }

        isLoading = false
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    private static func dateText(_ date: Date?) -> String {
        date.map(Self.dateFormatter.string(from:)) ?? "--"
    }

    private static func booleanText(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 7) {
                content
            }
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 112, alignment: .leading)

            Text(value)
                .textSelection(.enabled)
                .lineLimit(4)
        }
        .font(.callout)
    }
}

struct FileActionMenu: View {
    let item: FileItem
    let selectedURLs: Set<URL>
    let controller: ExplorerController
    let onRename: (FileItem) -> Void
    let onDetails: (FileItem) -> Void
    let onTransfer: (TransferRequest) -> Void

    private var transferURLs: [URL] {
        selectedURLs.contains(item.url) && !selectedURLs.isEmpty ? Array(selectedURLs) : [item.url]
    }

    var body: some View {
        Button("Open", systemImage: item.isNavigable ? "folder" : "arrow.up.forward.app") {
            if item.isNavigable {
                controller.navigate(to: item.url)
            } else {
                PlatformFileServices.open(item.url)
            }
        }

        Button("Rename", systemImage: "pencil") {
            onRename(item)
        }

        Button("Get Info", systemImage: "info.circle") {
            onDetails(item)
        }

        Button("Duplicate", systemImage: "plus.square.on.square") {
            controller.duplicate(item)
        }

        Divider()

        Button("Copy To...", systemImage: "doc.on.doc") {
            onTransfer(TransferRequest(operation: .copy, urls: transferURLs))
        }

        Button("Move To...", systemImage: "folder") {
            onTransfer(TransferRequest(operation: .move, urls: transferURLs))
        }

        #if os(macOS)
        Button("Reveal in Finder", systemImage: "finder") {
            PlatformFileServices.reveal(item.url)
        }
        #endif

        Divider()

        Button("Move to Trash", systemImage: "trash", role: .destructive) {
            let items = controller.visibleItems.filter { transferURLs.contains($0.url) }
            controller.trash(items.isEmpty ? [item] : items)
        }
    }
}
