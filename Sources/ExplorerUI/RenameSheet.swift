import ExplorerCore
import SwiftUI

struct RenameSheet: View {
    let item: FileItem
    let onRename: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(item: FileItem, onRename: @escaping (String) -> Void) {
        self.item = item
        self.onRename = onRename
        _name = State(initialValue: item.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename")
                .font(.headline)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }

                Button("Rename") {
                    onRename(name)
                    dismiss()
                }
                .buttonStyle(.glassProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}

