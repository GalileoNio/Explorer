import SwiftUI

enum PathBarPresentation {
    case content
    case titleBar

    var usesGlassChrome: Bool {
        self == .content
    }
}

struct PathBar: View {
    let currentURL: URL
    let presentation: PathBarPresentation
    let onNavigate: (URL) -> Void

    @State private var isEditingPath = false
    @State private var draftPath = ""
    @FocusState private var isPathFieldFocused: Bool

    private var components: [(title: String, url: URL)] {
        let pathComponents = currentURL.standardizedFileURL.pathComponents
        var runningURL = URL(fileURLWithPath: "/")
        var result: [(String, URL)] = [("/", runningURL)]

        for component in pathComponents.dropFirst() {
            runningURL.appendPathComponent(component)
            result.append((component, runningURL))
        }

        return result
    }

    var body: some View {
        pathBarContent
            .wrappedInGlassContainer(when: presentation.usesGlassChrome)
            .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.smooth(duration: 0.2), value: isEditingPath)
        .onAppear {
            draftPath = currentURL.path
        }
        .onChange(of: currentURL) { _, newURL in
            if !isEditingPath {
                draftPath = newURL.path
            }
        }
    }

    @ViewBuilder
    private var pathBarContent: some View {
        if isEditingPath {
            editablePath
                .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
            breadcrumbPath
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private var breadcrumbPath: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                        breadcrumbComponent(index: index, component: component)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                beginEditing()
            } label: {
                Label("Edit Path", systemImage: "text.cursor")
            }
            .labelStyle(.iconOnly)
            .controlSize(.small)
            .help("Edit Path")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func breadcrumbComponent(index: Int, component: (title: String, url: URL)) -> some View {
        HStack(spacing: 6) {
            if index > 0 {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button {
                onNavigate(component.url)
            } label: {
                Text(component.title)
                    .lineLimit(1)
            }
            .pathBarButtonStyle(useGlass: presentation.usesGlassChrome)
            .controlSize(.small)
        }
    }

    private var editablePath: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)

            TextField("Path", text: $draftPath)
                .textFieldStyle(.plain)
                .focused($isPathFieldFocused)
                .onSubmit(commitPath)

            Button {
                commitPath()
            } label: {
                Label("Go", systemImage: "arrow.forward")
            }
            .labelStyle(.iconOnly)
            .pathBarButtonStyle(useGlass: presentation.usesGlassChrome)
            .controlSize(.small)
            .help("Go")

            Button {
                cancelEditing()
            } label: {
                Label("Cancel", systemImage: "xmark")
            }
            .labelStyle(.iconOnly)
            .pathBarButtonStyle(useGlass: presentation.usesGlassChrome)
            .controlSize(.small)
            .help("Cancel")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .pathBarGlassBackground(when: presentation.usesGlassChrome)
    }

    private func beginEditing() {
        draftPath = currentURL.path
        withAnimation(.smooth(duration: 0.2)) {
            isEditingPath = true
        }

        Task { @MainActor in
            await Task.yield()
            isPathFieldFocused = true
        }
    }

    private func commitPath() {
        let trimmedPath = draftPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            cancelEditing()
            return
        }

        isPathFieldFocused = false
        withAnimation(.smooth(duration: 0.18)) {
            isEditingPath = false
        }
        onNavigate(url(for: trimmedPath))
    }

    private func cancelEditing() {
        draftPath = currentURL.path
        isPathFieldFocused = false
        withAnimation(.smooth(duration: 0.18)) {
            isEditingPath = false
        }
    }

    private func url(for path: String) -> URL {
        if path.lowercased().hasPrefix("file://"), let fileURL = URL(string: path), fileURL.isFileURL {
            return fileURL.standardizedFileURL
        }

        let expandedPath = (path as NSString).expandingTildeInPath
        if expandedPath.hasPrefix("/") {
            return URL(fileURLWithPath: expandedPath).standardizedFileURL
        }

        return currentURL.appendingPathComponent(expandedPath).standardizedFileURL
    }
}

private extension View {
    @ViewBuilder
    func wrappedInGlassContainer(when isEnabled: Bool) -> some View {
        if isEnabled {
            GlassEffectContainer(spacing: 6) {
                self
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func pathBarButtonStyle(useGlass: Bool) -> some View {
        if useGlass {
            self.buttonStyle(.glass)
        } else {
            self
        }
    }

    @ViewBuilder
    func pathBarGlassBackground(when isEnabled: Bool) -> some View {
        if isEnabled {
            self.glassEffect(.regular, in: Capsule())
        } else {
            self
        }
    }
}
