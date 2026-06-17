import SwiftUI

struct StatusStrip: View {
    let itemCount: Int
    let selectedCount: Int
    let loadedAt: Date?
    @Binding var iconSize: Double
    @State private var isIconSizeExpanded = false

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 12) {
                Label("\(itemCount) items", systemImage: "folder")

                if selectedCount > 0 {
                    Label("\(selectedCount) selected", systemImage: "checkmark.circle")
                }

                Spacer()

                if let loadedAt {
                    Text("Updated \(loadedAt, style: .time)")
                }

                iconSizeControl
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .glassEffect(.regular, in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var iconSizeControl: some View {
        HStack(spacing: isIconSizeExpanded ? 8 : 0) {
            Button {
                withAnimation(.smooth(duration: 0.22)) {
                    isIconSizeExpanded.toggle()
                }
            } label: {
                Label("Icon Size", systemImage: "photo")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .controlSize(.small)
            .help("Icon Size")

            Slider(value: $iconSize, in: 28...80, step: 2)
                .frame(width: isIconSizeExpanded ? 136 : 0, alignment: .leading)
            .opacity(isIconSizeExpanded ? 1 : 0)
            .clipped()
            .allowsHitTesting(isIconSizeExpanded)
        }
        .animation(.smooth(duration: 0.22), value: isIconSizeExpanded)
        .help("Icon Size")
    }
}
