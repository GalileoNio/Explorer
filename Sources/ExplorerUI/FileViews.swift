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
    let controller: ExplorerController
    let onRename: (FileItem) -> Void
    let onTransfer: (TransferRequest) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 112, maximum: 152), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(items) { item in
                    FileTile(
                        item: item,
                        isSelected: selectedURLs.contains(item.url),
                        controller: controller,
                        onRename: onRename,
                        onTransfer: onTransfer
                    )
                }
            }
            .padding(12)
        }
    }
}

struct FileTile: View {
    let item: FileItem
    let isSelected: Bool
    let controller: ExplorerController
    let onRename: (FileItem) -> Void
    let onTransfer: (TransferRequest) -> Void

    var body: some View {
        VStack(spacing: 8) {
            FileIconView(item: item, size: 42)
            Text(item.name)
                .font(.callout)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .top)
        }
        .padding(8)
        .frame(width: 124, height: 118)
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
    let controller: ExplorerController
    let onRename: (FileItem) -> Void
    let onTransfer: (TransferRequest) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(items) { item in
                        FileListRow(
                            item: item,
                            isSelected: selectedURLs.contains(item.url),
                            controller: controller,
                            onRename: onRename,
                            onTransfer: onTransfer
                        )
                    }
                } header: {
                    FileListHeader()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

struct FileListHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("Name")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Modified")
                .frame(width: 140, alignment: .leading)
            Text("Size")
                .frame(width: 90, alignment: .trailing)
            Text("Kind")
                .frame(width: 120, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial)
    }
}

struct FileListRow: View {
    let item: FileItem
    let isSelected: Bool
    let controller: ExplorerController
    let onRename: (FileItem) -> Void
    let onTransfer: (TransferRequest) -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                FileIconView(item: item, size: 20)
                Text(item.name)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.modifiedAt.map(Self.dateFormatter.string(from:)) ?? "--")
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)

            Text(item.formattedSize)
                .lineLimit(1)
                .frame(width: 90, alignment: .trailing)

            Text(item.displayType)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)
        }
        .font(.callout)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
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
                onTransfer: onTransfer
            )
        }
        .onDrag {
            NSItemProvider(object: item.url as NSURL)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

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

struct FileActionMenu: View {
    let item: FileItem
    let selectedURLs: Set<URL>
    let controller: ExplorerController
    let onRename: (FileItem) -> Void
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
