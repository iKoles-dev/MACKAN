import AppKit
import SwiftUI

import MACKANKit

struct LabelsManagerSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLabelID: ModuleLabelSummary.ID?
    @State private var originalName: String?
    @State private var originalInstanceName: String?
    @State private var draft = LabelDraftState()
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var isConfirmingDelete = false
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 8) {
                List(model.manageableModuleLabels, selection: $selectedLabelID) { label in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label.name)
                            Text(scopeTitle(label.instanceName))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Circle()
                            .fill(color(for: label))
                            .frame(width: 12, height: 12)
                    }
                    .tag(label.id)
                }
                .frame(minWidth: 220)

                HStack {
                    Button {
                        startNewLabel()
                    } label: {
                        Label("New", systemImage: "plus")
                    }
                    .disabled(isBusy)

                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(isBusy || selectedLabel == nil)
                }
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                Text(selectedLabel == nil && originalName == nil ? "New Label" : "Edit Label")
                    .font(.headline)

                Form {
                    TextField("Name", text: $draft.name)
                        .focused($isNameFieldFocused)

                    Picker("Scope", selection: $draft.instanceName) {
                        Text("Global").tag(String?.none)
                        ForEach(model.instances) { instance in
                            Text(instance.name).tag(String?.some(instance.id))
                        }
                    }

                    Toggle("Use color", isOn: $draft.usesColor)

                    ColorPicker("Color", selection: $draft.color)
                        .disabled(!draft.usesColor)

                    HStack(spacing: 8) {
                        ForEach(LabelDraftState.presetColorHexes, id: \.self) { colorHex in
                            Button {
                                draft.usesColor = true
                                draft.color = Color(mackanHex: colorHex) ?? .accentColor
                            } label: {
                                Circle()
                                    .fill(Color(mackanHex: colorHex) ?? .accentColor)
                                    .frame(width: 18, height: 18)
                            }
                            .buttonStyle(.plain)
                            .help(colorHex)
                        }
                    }

                    Toggle("Hide from other filters", isOn: $draft.hide)
                    Toggle("Notify on changes", isOn: $draft.notifyOnChange)
                    Toggle("Remove on changes", isOn: $draft.removeOnChange)
                    Toggle("Alert on install", isOn: $draft.alertOnInstall)
                    Toggle("Remove on install", isOn: $draft.removeOnInstall)
                    Toggle("Hold version", isOn: $draft.holdVersion)
                    Toggle("Ignore missing files", isOn: $draft.ignoreMissingFiles)

                    LabeledContent("Assigned mods", value: selectedLabel?.identifiers.count.formatted() ?? "0")
                }

                Spacer()

                HStack {
                    Button("Close", role: .cancel) {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button {
                        saveLabel()
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isBusy || (!canSave && !isNameFieldFocused))
                }
            }
            .padding()
            .frame(minWidth: CGFloat(ModalSheetLayoutPolicy.compactIdealWidth), maxWidth: .infinity)
        }
        .mackanModalSheetFrame(.wide)
        .onAppear {
            if selectedLabelID == nil {
                selectedLabelID = model.manageableModuleLabels.first?.id
            }
            syncDraft()
        }
        .onChange(of: selectedLabelID) { _ in
            syncDraft()
        }
        .confirmationDialog("Delete label?", isPresented: $isConfirmingDelete) {
            Button("Delete Label", role: .destructive) {
                deleteSelectedLabel()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Label update failed", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var selectedLabel: ModuleLabelSummary? {
        guard let selectedLabelID else {
            return nil
        }
        return model.manageableModuleLabels.first { $0.id == selectedLabelID }
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var errorIsPresented: Binding<Bool> {
        Binding {
            errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                errorMessage = nil
            }
        }
    }

    private func syncDraft() {
        guard let selectedLabel else {
            return
        }
        draft = LabelDraftState(label: selectedLabel)
        originalName = selectedLabel.name
        originalInstanceName = selectedLabel.instanceName
        isNameFieldFocused = false
    }

    private func startNewLabel() {
        selectedLabelID = nil
        originalName = nil
        originalInstanceName = nil
        draft = LabelDraftState(instanceName: model.selectedInstanceID)
        isNameFieldFocused = true
    }

    private func saveLabel() {
        isNameFieldFocused = false
        NSApp.keyWindow?.makeFirstResponder(nil)
        Task { @MainActor in
            await Task.yield()
            guard let edit = draft.edit else {
                return
            }
            isBusy = true
            defer { isBusy = false }
            do {
                try await model.saveLabel(
                    originalName: originalName,
                    originalInstanceName: originalInstanceName,
                    label: edit)
                selectedLabelID = model.manageableModuleLabels.first {
                    $0.name.localizedCaseInsensitiveCompare(edit.name) == .orderedSame
                        && $0.instanceName == edit.instanceName
                }?.id
                syncDraft()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteSelectedLabel() {
        guard let selectedLabel else {
            return
        }
        Task {
            isBusy = true
            defer { isBusy = false }
            do {
                try await model.deleteLabel(name: selectedLabel.name, instanceName: selectedLabel.instanceName)
                selectedLabelID = model.manageableModuleLabels.first?.id
                if selectedLabelID == nil {
                    startNewLabel()
                } else {
                    syncDraft()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func scopeTitle(_ instanceName: String?) -> String {
        guard let instanceName else {
            return "Global"
        }
        return model.instances.first { $0.id == instanceName }?.name ?? instanceName
    }

    private func color(for label: ModuleLabelSummary) -> Color {
        label.colorHex.flatMap { Color(mackanHex: $0) } ?? .secondary.opacity(0.35)
    }
}

private struct LabelDraftState {
    var name: String
    var instanceName: String?
    var usesColor: Bool
    var color: Color
    var hide: Bool
    var notifyOnChange: Bool
    var removeOnChange: Bool
    var alertOnInstall: Bool
    var removeOnInstall: Bool
    var holdVersion: Bool
    var ignoreMissingFiles: Bool

    static let presetColorHexes = [
        "#98FB98",
        "#DB7093",
        "#FFFFB0",
        "#5AC8FA",
        "#AF52DE",
        "#FF9500",
    ]

    init(instanceName: String? = nil) {
        self.name = ""
        self.instanceName = instanceName
        self.usesColor = true
        self.color = Color(mackanHex: "#98FB98") ?? .accentColor
        self.hide = false
        self.notifyOnChange = false
        self.removeOnChange = false
        self.alertOnInstall = false
        self.removeOnInstall = false
        self.holdVersion = false
        self.ignoreMissingFiles = false
    }

    init(label: ModuleLabelSummary) {
        self.name = label.name
        self.instanceName = label.instanceName
        self.usesColor = label.colorHex != nil
        self.color = label.colorHex.flatMap { Color(mackanHex: $0) } ?? .accentColor
        self.hide = label.hide
        self.notifyOnChange = label.notifyOnChange
        self.removeOnChange = label.removeOnChange
        self.alertOnInstall = label.alertOnInstall
        self.removeOnInstall = label.removeOnInstall
        self.holdVersion = label.holdVersion
        self.ignoreMissingFiles = label.ignoreMissingFiles
    }

    var edit: ModuleLabelEdit? {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else {
            return nil
        }
        return ModuleLabelEdit(
            name: cleanedName,
            instanceName: instanceName,
            colorHex: usesColor ? color.mackanHexString : nil,
            hide: hide,
            notifyOnChange: notifyOnChange,
            removeOnChange: removeOnChange,
            alertOnInstall: alertOnInstall,
            removeOnInstall: removeOnInstall,
            holdVersion: holdVersion,
            ignoreMissingFiles: ignoreMissingFiles)
    }
}

extension Color {
    init?(mackanHex: String) {
        let value = mackanHex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count == 7, value.first == "#",
              let red = UInt8(value.dropFirst().prefix(2), radix: 16),
              let green = UInt8(value.dropFirst(3).prefix(2), radix: 16),
              let blue = UInt8(value.dropFirst(5).prefix(2), radix: 16) else {
            return nil
        }
        self.init(nsColor: NSColor(
            srgbRed: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: 1))
    }

    var mackanHexString: String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? .controlAccentColor
        let red = Int((nsColor.redComponent * 255).rounded())
        let green = Int((nsColor.greenComponent * 255).rounded())
        let blue = Int((nsColor.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
