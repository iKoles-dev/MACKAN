import SwiftUI

import MACKANKit

struct ImportDownloadsOptionsSheet: View {
    let fileCount: Int
    @Binding var installImportedModules: Bool
    @Binding var deleteImportedFiles: Bool
    @Binding var previewBeforeInstall: Bool
    let onCancel: () -> Void
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import Downloads")
                .font(.headline)

            Text(fileCount == 1 ? "Import 1 selected download." : "Import \(fileCount.formatted()) selected downloads.")
                .foregroundStyle(.secondary)

            Toggle("Install imported modules", isOn: $installImportedModules)
            Toggle("Preview install changes before applying", isOn: $previewBeforeInstall)
                .disabled(!installImportedModules)
            Toggle("Delete imported files after successful import", isOn: $deleteImportedFiles)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Import", action: onImport)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .mackanModalSheetFrame(.compact)
    }
}
