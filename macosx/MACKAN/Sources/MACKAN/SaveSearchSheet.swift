import SwiftUI

import MACKANKit

struct SaveSearchSheet: View {
    @Binding var name: String
    let canSaveCurrentSearch: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save Search")
                .font(.headline)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding()
        .mackanModalSheetFrame(.compact)
    }

    private var canSave: Bool {
        canSaveCurrentSearch && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

