import SwiftUI

struct PathBar: View {
    let currentURL: URL
    let onNavigate: (URL) -> Void

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
        GlassEffectContainer(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(components.enumerated()), id: \.offset) { index, component in
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
                        .buttonStyle(.glass)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
        }
    }
}

