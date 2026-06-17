import SwiftUI

struct StatusStrip: View {
    let itemCount: Int
    let selectedCount: Int
    let loadedAt: Date?

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
}

