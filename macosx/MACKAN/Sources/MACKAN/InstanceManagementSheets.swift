import SwiftUI

import MACKANKit

struct InstanceManagementSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let onAdd: () -> Void
    let onClone: () -> Void
    let onFake: () -> Void
    @State private var pendingRename: InstanceManagementRow?
    @State private var renameName = ""
    @State private var pendingForget: InstanceManagementRow?
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "externaldrive.badge.gearshape")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Manage Instances")
                        .font(.title3.weight(.semibold))
                    Text("\(model.instanceManagementRows.count.formatted()) configured")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isWorking {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            HStack(spacing: 8) {
                Button {
                    onAdd()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                Button {
                    onClone()
                } label: {
                    Label("Clone", systemImage: "doc.on.doc")
                }
                .disabled(!canClone)
                Button {
                    onFake()
                } label: {
                    Label("Fake", systemImage: "hammer")
                }
                Spacer()
            }

            Divider()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.instanceManagementRows) { row in
                        InstanceManagementRowView(
                            row: row,
                            isWorking: isWorking,
                            onSelect: { select(row) },
                            onSetDefault: { setDefault(row) },
                            onReveal: { reveal(row) },
                            onRename: { beginRename(row) },
                            onForget: { pendingForget = row })
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(minHeight: 300)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .mackanModalSheetFrame(.wide)
        .sheet(isPresented: isShowingRenameSheet) {
            InstanceManagementRenameSheet(
                originalName: pendingRename?.name ?? "",
                name: $renameName,
                isRenaming: isWorking,
                onCancel: { clearRename() },
                onRename: { renamePendingInstance() })
        }
        .confirmationDialog(
            "Forget Instance?",
            isPresented: isConfirmingForget,
            presenting: pendingForget
        ) { row in
            Button("Forget \(row.name)", role: .destructive) {
                forget(row)
            }
            Button("Cancel", role: .cancel) {}
        } message: { row in
            Text("This removes \(row.name) from CKAN's instance list. It does not delete the game folder.")
        }
    }

    private var canClone: Bool {
        model.selectedInstance.map(\.isValid) ?? false
    }

    private var isShowingRenameSheet: Binding<Bool> {
        Binding {
            pendingRename != nil
        } set: { isPresented in
            if !isPresented {
                clearRename()
            }
        }
    }

    private var isConfirmingForget: Binding<Bool> {
        Binding {
            pendingForget != nil
        } set: { isPresented in
            if !isPresented {
                pendingForget = nil
            }
        }
    }

    private func select(_ row: InstanceManagementRow) {
        runInstanceAction {
            await model.selectInstance(row.id)
        }
    }

    private func setDefault(_ row: InstanceManagementRow) {
        runInstanceAction {
            try await model.setDefaultInstance(row.id)
        }
    }

    private func reveal(_ row: InstanceManagementRow) {
        do {
            try model.openInstanceDirectory(row.id)
            errorMessage = nil
        } catch {
            handle(error)
        }
    }

    private func beginRename(_ row: InstanceManagementRow) {
        pendingRename = row
        renameName = row.name
    }

    private func renamePendingInstance() {
        guard let row = pendingRename else {
            return
        }
        runInstanceAction {
            try await model.renameInstance(row.id, to: renameName)
            clearRename()
        }
    }

    private func forget(_ row: InstanceManagementRow) {
        runInstanceAction {
            try await model.forgetInstance(row.id)
            pendingForget = nil
        }
    }

    private func clearRename() {
        pendingRename = nil
        renameName = ""
    }

    private func runInstanceAction(_ action: @escaping @MainActor () async throws -> Void) {
        Task { @MainActor in
            isWorking = true
            defer { isWorking = false }
            do {
                try await action()
                errorMessage = nil
            } catch {
                handle(error)
            }
        }
    }

    private func handle(_ error: Error) {
        errorMessage = error.localizedDescription
        model.healthState = .failed(error.localizedDescription)
    }
}

private struct InstanceManagementRowView: View {
    let row: InstanceManagementRow
    let isWorking: Bool
    let onSelect: () -> Void
    let onSetDefault: () -> Void
    let onReveal: () -> Void
    let onRename: () -> Void
    let onForget: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: row.isDefault ? "star.fill" : instanceSymbol)
                .font(.title3)
                .foregroundStyle(row.isDefault ? .yellow : symbolColor)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(row.name)
                        .font(.headline)
                        .lineLimit(1)
                    if row.isSelected {
                        InstanceStatusBadge(title: "Selected", systemImage: "checkmark.circle.fill")
                    }
                    if row.isDefault {
                        InstanceStatusBadge(title: "Default", systemImage: "star.fill")
                    }
                    if !row.isValid {
                        InstanceStatusBadge(title: "Invalid", systemImage: "exclamationmark.triangle.fill")
                    }
                }

                HStack(spacing: 10) {
                    Text(row.game)
                    Text(row.gameVersion)
                    Text(row.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            HStack(spacing: 5) {
                Button(action: onSelect) {
                    Image(systemName: "cursorarrow.click.2")
                }
                .disabled(isWorking || row.isSelected)
                .help("Select instance")

                Button(action: onSetDefault) {
                    Image(systemName: "star")
                }
                .disabled(isWorking || !row.canSetDefault)
                .help("Set as default")

                Button(action: onReveal) {
                    Image(systemName: "folder")
                }
                .disabled(isWorking || !row.canReveal)
                .help("Show in Finder")

                Button(action: onRename) {
                    Image(systemName: "pencil")
                }
                .disabled(isWorking || !row.canRename)
                .help("Rename")

                Button(role: .destructive, action: onForget) {
                    Image(systemName: "trash")
                }
                .disabled(isWorking || !row.canForget)
                .help("Forget instance")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .frame(minWidth: 145, alignment: .trailing)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var instanceSymbol: String {
        row.isValid ? "shippingbox" : "exclamationmark.triangle"
    }

    private var symbolColor: Color {
        row.isValid ? .secondary : .orange
    }
}

private struct InstanceStatusBadge: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct InstanceManagementRenameSheet: View {
    let originalName: String
    @Binding var name: String
    let isRenaming: Bool
    let onCancel: () -> Void
    let onRename: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename Instance")
                .font(.headline)

            Form {
                TextField("Name", text: $name)
                    .disabled(isRenaming)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Rename", action: onRename)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canRename)
            }
        }
        .padding()
        .mackanModalSheetFrame(.compact)
    }

    private var canRename: Bool {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !isRenaming
            && !cleanedName.isEmpty
            && cleanedName != originalName
    }
}

