import AppKit
import SwiftUI

import MACKANKit

struct StabilityPreferencesView: View {
    @ObservedObject var model: AppModel
    @State private var overallTolerance = "stable"
    @State private var selectedOverrideID: ModuleStabilityTolerance.ID?
    @State private var overrideDraftIdentifier = ""
    @State private var overrideDraftTolerance = "stable"
    @State private var isBusy = false
    @State private var statusMessage: String?

    var body: some View {
        PreferencesPaneScrollView {
            VStack(alignment: .leading, spacing: 12) {
            if let instance = model.selectedInstance {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(instance.name)
                            .font(.headline)
                        Text(instance.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    Button {
                        reloadStability()
                    } label: {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }
                    .disabled(isBusy)
                }

                if let result = model.stabilityTolerance {
                    Form {
                        LabeledContent("Game", value: result.game)

                        Picker("Overall tolerance", selection: $overallTolerance) {
                            ForEach(availableTolerances, id: \.self) { tolerance in
                                Text(displayName(for: tolerance)).tag(tolerance)
                            }
                        }

                        LabeledContent("Module overrides", value: result.moduleStabilityTolerances.count.formatted())
                    }

                    Table(result.moduleStabilityTolerances, selection: $selectedOverrideID) {
                        TableColumn("Identifier", value: \.identifier)
                        TableColumn("Tolerance") { override in
                            Text(displayName(for: override.stabilityTolerance))
                        }
                    }
                    .frame(minHeight: 150)

                    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                        GridRow {
                            Button {
                                useSelectedModule()
                            } label: {
                                Label("Add Selected Module", systemImage: "plus")
                            }
                            .disabled(isBusy || model.selectedModule == nil)

                            TextField("Module identifier", text: $overrideDraftIdentifier)
                                .textFieldStyle(.roundedBorder)
                                .disabled(isBusy)

                            Picker("Tolerance", selection: $overrideDraftTolerance) {
                                ForEach(availableTolerances, id: \.self) { tolerance in
                                    Text(displayName(for: tolerance)).tag(tolerance)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                            .disabled(isBusy)
                        }

                        GridRow {
                            Button(role: .destructive) {
                                clearOverride()
                            } label: {
                                Label("Clear Override", systemImage: "xmark.circle")
                            }
                            .disabled(isBusy || cleanedClearIdentifier.isEmpty)

                            HStack {
                                Button {
                                    saveOverride()
                                } label: {
                                    Label("Save Override", systemImage: "checkmark")
                                }
                                .disabled(isBusy || cleanedOverrideIdentifier.isEmpty)

                                Spacer()
                            }
                            .gridCellColumns(2)
                        }
                    }

                    if let statusMessage {
                        Label(statusMessage, systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Spacer()

                        Button {
                            saveOverallTolerance()
                        } label: {
                            Label("Save Overall", systemImage: "checkmark")
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(isBusy || overallTolerance == result.overallStabilityTolerance)
                    }
                } else {
                    Spacer()
                    ProgressView()
                        .frame(maxWidth: .infinity)
                    Spacer()
                }
            } else {
                Spacer()
                Label("No game instance selected.", systemImage: "shippingbox")
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        }
        .task {
            await loadStability()
        }
        .onChange(of: model.selectedInstanceID) { _ in
            Task {
                await loadStability()
            }
        }
        .onChange(of: model.stabilityTolerance) { result in
            sync(from: result)
        }
        .onChange(of: selectedOverrideID) { identifier in
            syncOverrideDraft(identifier)
        }
        .alert("Stability update failed", isPresented: settingsErrorIsPresented) {
            Button("OK", role: .cancel) {
                model.clearSettingsError()
            }
        } message: {
            Text(model.settingsError ?? "")
        }
    }

    private var availableTolerances: [String] {
        let tolerances = model.stabilityTolerance?.availableStabilityTolerances ?? []
        return tolerances.isEmpty ? ["stable", "testing", "development"] : tolerances
    }

    private var cleanedOverrideIdentifier: String {
        overrideDraftIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanedClearIdentifier: String {
        selectedOverrideID ?? cleanedOverrideIdentifier
    }

    private var settingsErrorIsPresented: Binding<Bool> {
        Binding {
            model.settingsError != nil
        } set: { isPresented in
            if !isPresented {
                model.clearSettingsError()
            }
        }
    }

    private func displayName(for tolerance: String) -> String {
        switch tolerance {
        case "stable":
            return "Stable"
        case "testing":
            return "Testing"
        case "development":
            return "Development"
        default:
            return tolerance
                .split(separator: "_")
                .map { $0.capitalized }
                .joined(separator: " ")
        }
    }

    private func loadStability() async {
        guard model.selectedInstance != nil else {
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            try await model.loadStabilityTolerance()
            statusMessage = nil
        } catch {
            statusMessage = nil
        }
    }

    private func reloadStability() {
        Task {
            await loadStability()
        }
    }

    private func saveOverallTolerance() {
        Task {
            isBusy = true
            defer { isBusy = false }
            do {
                try await model.updateStabilityTolerance(overallTolerance)
                statusMessage = "Stability tolerance saved."
            } catch {
                statusMessage = nil
            }
        }
    }

    private func saveOverride() {
        Task {
            isBusy = true
            defer { isBusy = false }
            do {
                try await model.updateModuleStabilityTolerance(
                    identifier: cleanedOverrideIdentifier,
                    stabilityTolerance: overrideDraftTolerance)
                selectedOverrideID = cleanedOverrideIdentifier
                statusMessage = "Module override saved."
            } catch {
                statusMessage = nil
            }
        }
    }

    private func clearOverride() {
        let identifier = cleanedClearIdentifier
        guard !identifier.isEmpty else {
            return
        }
        Task {
            isBusy = true
            defer { isBusy = false }
            do {
                try await model.updateModuleStabilityTolerance(
                    identifier: identifier,
                    stabilityTolerance: nil)
                selectedOverrideID = nil
                overrideDraftIdentifier = ""
                statusMessage = "Module override cleared."
            } catch {
                statusMessage = nil
            }
        }
    }

    private func useSelectedModule() {
        guard let module = model.selectedModule else {
            return
        }
        overrideDraftIdentifier = module.identifier
        overrideDraftTolerance = model.stabilityTolerance?.overallStabilityTolerance ?? availableTolerances.first ?? "stable"
        selectedOverrideID = nil
    }

    private func sync(from result: StabilityToleranceResult?) {
        guard let result else {
            overallTolerance = "stable"
            selectedOverrideID = nil
            overrideDraftIdentifier = ""
            overrideDraftTolerance = "stable"
            return
        }
        overallTolerance = result.overallStabilityTolerance
        if !availableTolerances.contains(overrideDraftTolerance) {
            overrideDraftTolerance = result.overallStabilityTolerance
        }
        if let selectedOverrideID,
           result.moduleStabilityTolerances.contains(where: { $0.identifier == selectedOverrideID }) {
            syncOverrideDraft(selectedOverrideID)
        }
    }

    private func syncOverrideDraft(_ identifier: String?) {
        guard
            let identifier,
            let override = model.stabilityTolerance?.moduleStabilityTolerances.first(where: { $0.identifier == identifier })
        else {
            return
        }
        overrideDraftIdentifier = override.identifier
        overrideDraftTolerance = override.stabilityTolerance
    }
}

