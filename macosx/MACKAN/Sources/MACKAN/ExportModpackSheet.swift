import AppKit
import SwiftUI
import UniformTypeIdentifiers

import MACKANKit

private enum ModpackRelationshipKind: String, CaseIterable, Identifiable {
    case depends
    case recommends
    case suggests
    case ignore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .depends:
            "Depends"
        case .recommends:
            "Recommends"
        case .suggests:
            "Suggests"
        case .ignore:
            "Ignore"
        }
    }
}

struct ExportModpackSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var identifier = ""
    @State private var name = ""
    @State private var abstractText = ""
    @State private var author = ""
    @State private var version = ""
    @State private var license = "unknown"
    @State private var gameVersionMin = ""
    @State private var gameVersionMax = ""
    @State private var includeVersions = false
    @State private var includeOptionalRelationships = false
    @State private var relationshipAssignments: [String: String] = [:]
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Export Modpack")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                    GridRow {
                        labeledTextField("Identifier", text: $identifier)
                        labeledTextField("Name", text: $name)
                    }
                    GridRow {
                        labeledTextField("Summary", text: $abstractText)
                        labeledTextField("Author", text: $author)
                    }
                    GridRow {
                        labeledTextField("Version", text: $version)
                        labeledTextField("License", text: $license)
                    }
                    GridRow {
                        labeledTextField("Min game version", text: $gameVersionMin)
                        labeledTextField("Max game version", text: $gameVersionMax)
                    }
                }

                Toggle("Include pinned mod versions", isOn: $includeVersions)
                Toggle("Include recommendations from dependencies", isOn: $includeOptionalRelationships)

                if !installedRelationshipModules.isEmpty {
                    relationshipList
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Export") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSaving || !canExport)
            }
        }
        .padding()
        .mackanModalSheetFrame(.wide)
        .onAppear(perform: resetDefaults)
    }

    private func labeledTextField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, text: text)
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
        }
    }

    private var relationshipList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Relationships")
                .font(.headline)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(installedRelationshipModules) { module in
                        relationshipRow(for: module)
                    }
                }
                .padding(10)
            }
            .frame(
                minHeight: CGFloat(ModalSheetLayoutPolicy.exportModpackRelationshipListMinimumHeight),
                maxHeight: CGFloat(ModalSheetLayoutPolicy.exportModpackRelationshipListMaximumHeight))
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor))
            }
        }
    }

    private func relationshipRow(for module: ModuleSummary) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(module.name)
                    .lineLimit(1)
                Text(module.identifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            Picker("", selection: relationshipBinding(for: module.identifier)) {
                ForEach(ModpackRelationshipKind.allCases) { kind in
                    Text(kind.title).tag(kind.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 150)
        }
        .padding(.vertical, 2)
    }

    private var canExport: Bool {
        isIdentifierValid
            && !trimmed(name).isEmpty
            && !trimmed(version).isEmpty
    }

    private var isIdentifierValid: Bool {
        let value = trimmed(identifier)
        guard let firstScalar = value.unicodeScalars.first,
              isIdentifierAlphaNumeric(firstScalar)
        else {
            return false
        }
        return value.unicodeScalars.allSatisfy { scalar in
            isIdentifierAlphaNumeric(scalar) || scalar == "-"
        }
    }

    private var installedRelationshipModules: [ModuleSummary] {
        model.modules
            .filter { $0.isInstalled && !$0.isAutodetected }
            .sorted {
                let left = $0.name.localizedCaseInsensitiveCompare($1.name)
                if left == .orderedSame {
                    return $0.identifier.localizedCaseInsensitiveCompare($1.identifier) == .orderedAscending
                }
                return left == .orderedAscending
            }
    }

    private func resetDefaults() {
        let instanceName = model.selectedInstance?.name ?? "MACKAN"
        let defaultName = "\(instanceName) Modpack"
        name = defaultName
        identifier = sanitizedIdentifier(defaultName)
        abstractText = "Modpack exported from \(instanceName)."
        author = NSUserName()
        version = Self.defaultVersion()
        license = "unknown"
        gameVersionMin = model.selectedInstance?.gameVersion ?? ""
        gameVersionMax = model.selectedInstance?.gameVersion ?? ""
        includeVersions = false
        includeOptionalRelationships = false
        relationshipAssignments = Dictionary(uniqueKeysWithValues: installedRelationshipModules.map {
            ($0.identifier, ModpackRelationshipKind.depends.rawValue)
        })
        errorMessage = nil
    }

    private func save() {
        Task { @MainActor in
            isSaving = true
            defer { isSaving = false }
            do {
                let result = try await model.exportModpack(draft: ModpackExportDraft(
                    identifier: trimmed(identifier),
                    name: trimmed(name),
                    abstract: trimmed(abstractText),
                    author: trimmed(author),
                    version: trimmed(version),
                    license: trimmed(license),
                    gameVersionMin: trimmedOptional(gameVersionMin),
                    gameVersionMax: trimmedOptional(gameVersionMax),
                    includeVersions: includeVersions,
                    includeOptionalRelationships: includeOptionalRelationships,
                    relationshipAssignments: installedRelationshipModules.map { module in
                        ModpackRelationshipAssignment(
                            identifier: module.identifier,
                            kind: relationshipAssignments[module.identifier] ?? ModpackRelationshipKind.depends.rawValue)
                    }))
                let panel = NSSavePanel()
                panel.canCreateDirectories = true
                panel.nameFieldStringValue = result.suggestedFileName
                if let contentType = UTType(filenameExtension: "ckan") {
                    panel.allowedContentTypes = [contentType]
                }
                guard panel.runModal() == .OK, let url = panel.url else {
                    return
                }
                try result.contents.write(to: url, atomically: true, encoding: .utf8)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func relationshipBinding(for identifier: String) -> Binding<String> {
        Binding(
            get: { relationshipAssignments[identifier] ?? ModpackRelationshipKind.depends.rawValue },
            set: { relationshipAssignments[identifier] = $0 })
    }

    private func sanitizedIdentifier(_ value: String) -> String {
        let sanitized = value.unicodeScalars
            .map { scalar -> Character in
                isIdentifierAlphaNumeric(scalar) || scalar == "-" ? Character(scalar) : "-"
            }
        let joined = String(sanitized).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return joined.isEmpty ? "MACKAN-Modpack" : joined
    }

    private func isIdentifierAlphaNumeric(_ scalar: UnicodeScalar) -> Bool {
        ("A"..."Z").contains(Character(scalar))
            || ("a"..."z").contains(Character(scalar))
            || ("0"..."9").contains(Character(scalar))
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func trimmedOptional(_ value: String) -> String? {
        let cleaned = trimmed(value)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func defaultVersion() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd.HHmmss"
        return formatter.string(from: Date())
    }
}
