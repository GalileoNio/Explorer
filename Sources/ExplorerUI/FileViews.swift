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
        [GridItem(.adaptive(minimum: tileWidth, maximum: tileWidth + 16), spacing: FileGridMetrics.columnSpacing)]
    }

    private var tileWidth: CGFloat {
        FileGridMetrics.tileWidth(for: iconSize)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: FileGridMetrics.rowSpacing) {
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
            .padding(FileGridMetrics.contentPadding)
        }
        .fileDragSelection(coordinateSpaceName: selectionCoordinateSpace) { selectedURLs in
            controller.setSelectedURLs(selectedURLs)
        }
    }
}

private enum FileGridMetrics {
    static let columnSpacing: CGFloat = 4
    static let rowSpacing: CGFloat = 4
    static let contentPadding: CGFloat = 8
    static let iconLabelSpacing: CGFloat = 4

    static func tileWidth(for iconSize: CGFloat) -> CGFloat {
        max(96, min(iconSize * 1.9, 150))
    }

    static func tileHeight(for iconSize: CGFloat) -> CGFloat {
        max(94, iconSize * 1.18 + 44)
    }

    static func labelWidth(for iconSize: CGFloat, tileWidth: CGFloat) -> CGFloat {
        min(tileWidth - 12, max(iconSize * 1.5, 76))
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
        VStack(spacing: FileGridMetrics.iconLabelSpacing) {
            FileIconView(item: item, size: iconSize)
            Text(item.name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: labelWidth, height: 32, alignment: .top)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
        }
        .frame(width: tileWidth, height: tileHeight)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(.selection)
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture(count: 1).onEnded {
            controller.select(item)
        })
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            openOrNavigate(item)
        })
        .contextMenu {
            FileActionMenu(
                item: item,
                selectedItems: controller.selectedItems(containing: item),
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

    private var tileWidth: CGFloat {
        FileGridMetrics.tileWidth(for: iconSize)
    }

    private var tileHeight: CGFloat {
        FileGridMetrics.tileHeight(for: iconSize)
    }

    private var labelWidth: CGFloat {
        FileGridMetrics.labelWidth(for: iconSize, tileWidth: tileWidth)
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

    var body: some View {
        Table(of: FileItem.self, selection: selection) {
            TableColumn("Name") { item in
                tableCell(for: item) {
                    FileListNameCell(item: item, iconSize: listIconSize)
                }
            }
            .width(min: 180, ideal: 300, max: 520)

            TableColumn("Modified") { item in
                tableCell(for: item) {
                    Text(Self.dateText(item.modifiedAt))
                        .lineLimit(1)
                }
            }
            .width(min: 110, ideal: 138)

            TableColumn("Created") { item in
                tableCell(for: item) {
                    Text(Self.dateText(item.createdAt))
                        .lineLimit(1)
                }
            }
            .width(min: 110, ideal: 138)

            TableColumn("Size") { item in
                tableCell(for: item) {
                    Text(item.formattedSize)
                        .lineLimit(1)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .width(min: 72, ideal: 88)

            TableColumn("Kind") { item in
                tableCell(for: item) {
                    Text(item.displayType)
                        .lineLimit(1)
                }
            }
            .width(min: 120, ideal: 154)

            TableColumn("Extension") { item in
                tableCell(for: item) {
                    Text(extensionText(for: item))
                        .lineLimit(1)
                }
            }
            .width(min: 72, ideal: 88)
        } rows: {
            ForEach(items) { item in
                TableRow(item)
                    .contextMenu {
                        FileActionMenu(
                            item: item,
                            selectedItems: controller.selectedItems(containing: item),
                            controller: controller,
                            onRename: onRename,
                            onDetails: onDetails,
                            onTransfer: onTransfer
                        )
                    }
                    .itemProvider {
                        NSItemProvider(object: item.url as NSURL)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var listIconSize: CGFloat {
        min(max(iconSize * 0.42, 16), 26)
    }

    private var selection: Binding<Set<URL>> {
        Binding(
            get: { selectedURLs },
            set: { controller.setSelectedURLs($0) }
        )
    }

    @ViewBuilder
    private func tableCell<Content: View>(
        for item: FileItem,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                openOrNavigate(item)
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

    private func extensionText(for item: FileItem) -> String {
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

struct FileListNameCell: View {
    let item: FileItem
    let iconSize: CGFloat

    var body: some View {
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
                    Form {
                        Section {
                            header(details)
                        }

                        Section("General") {
                            detailRow("Kind", details.displayType)
                            detailRow("Size", details.formattedSize)
                            detailRow("Allocated", details.formattedAllocatedSize)
                            detailRow("Extension", details.pathExtension)
                            detailRow("Location", details.location)
                            detailRow("Path", details.url.path)
                            if let typeIdentifier = details.typeIdentifier {
                                detailRow("Type Identifier", typeIdentifier)
                            }
                        }

                        Section("Dates") {
                            detailRow("Created", Self.dateText(details.createdAt))
                            detailRow("Modified", Self.dateText(details.modifiedAt))
                            detailRow("Last Opened", Self.dateText(details.accessedAt))
                        }

                        Section("Access") {
                            detailRow("Readable", Self.booleanText(details.isReadable))
                            detailRow("Writable", Self.booleanText(details.isWritable))
                            detailRow("Executable", Self.booleanText(details.isExecutable))
                            detailRow("Hidden", Self.booleanText(details.isHidden))
                            detailRow("Owner", details.ownerAccountName ?? "--")
                            detailRow("Group", details.groupOwnerAccountName ?? "--")
                            detailRow("POSIX", details.formattedPOSIXPermissions)
                        }
                    }
                    .formStyle(.grouped)
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

    private func detailRow(_ label: String, _ value: String, lineLimit: Int = 4) -> some View {
        LabeledContent(label) {
            Text(value)
                .textSelection(.enabled)
                .lineLimit(lineLimit)
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
