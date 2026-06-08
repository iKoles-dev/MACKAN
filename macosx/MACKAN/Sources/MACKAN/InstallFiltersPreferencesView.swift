import AppKit
import SwiftUI

import MACKANKit

struct InstallFiltersPreferencesView: View {
    @ObservedObject var model: AppModel
    @State private var globalFiltersText = ""
    @State private var instanceFiltersText = ""
    @State private var isBusy = false
    @State private var statusMessage: String?

    var body: some View {
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
                        reloadFilters()
                    } label: {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }
                    .disabled(isBusy)
                }

                if let result = model.installFilters {
                    HStack(alignment: .top, spacing: 14) {
                        filterEditor(title: "Global filters for \(result.game)", text: $globalFiltersText)
                        filterEditor(title: "Instance filters", text: $instanceFiltersText)
                    }

                    if !result.presets.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Presets")
                                .font(.headline)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(result.presets) { preset in
                                        Button {
                                            appendPreset(preset)
                                        } label: {
                                            Label(preset.name, systemImage: "plus.circle")
                                        }
                                        .disabled(isBusy)
                                        .help(preset.filters.joined(separator: "\n"))
                                    }
                                }
                            }
                        }
                    }

                    Label(
                        "Changes affect future installations only; already installed files are unchanged.",
                        systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let statusMessage {
                        Label(statusMessage, systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Spacer()

                        Button(role: .destructive) {
                            clearFilters()
                        } label: {
                            Label("Clear", systemImage: "xmark.circle")
                        }
                        .disabled(isBusy || (globalFiltersText.isEmpty && instanceFiltersText.isEmpty))

                        Button {
                            saveFilters()
                        } label: {
                            Label("Save", systemImage: "checkmark")
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(isBusy || !hasChanges(from: result))
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
        .padding()
        .task {
            await loadFilters()
        }
        .onChange(of: model.selectedInstanceID) { _ in
            Task {
                await loadFilters()
            }
        }
        .onChange(of: model.installFilters) { result in
            sync(from: result)
        }
        .alert("Install filters update failed", isPresented: settingsErrorIsPresented) {
            Button("OK", role: .cancel) {
                model.clearSettingsError()
            }
        } message: {
            Text(model.settingsError ?? "")
        }
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

    private func filterEditor(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            TextEditor(text: text)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 245)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.separator, lineWidth: 1)
                }
        }
    }

    private func loadFilters() async {
        guard model.selectedInstance != nil else {
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            try await model.loadInstallFilters()
            statusMessage = nil
        } catch {
            statusMessage = nil
        }
    }

    private func reloadFilters() {
        Task {
            await loadFilters()
        }
    }

    private func appendPreset(_ preset: InstallFilterPreset) {
        var mergedFilters = filters(from: globalFiltersText)
        for filter in preset.filters {
            let cleanedFilter = filter.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanedFilter.isEmpty,
                  !mergedFilters.contains(where: {
                      $0.localizedCaseInsensitiveCompare(cleanedFilter) == .orderedSame
                  })
            else {
                continue
            }
            mergedFilters.append(cleanedFilter)
        }
        globalFiltersText = joined(mergedFilters)
        statusMessage = nil
    }

    private func clearFilters() {
        globalFiltersText = ""
        instanceFiltersText = ""
        statusMessage = nil
    }

    private func saveFilters() {
        Task {
            isBusy = true
            defer { isBusy = false }
            do {
                try await model.updateInstallFilters(
                    globalFilters: filters(from: globalFiltersText),
                    instanceFilters: filters(from: instanceFiltersText))
                statusMessage = "Install filters saved."
            } catch {
                statusMessage = nil
            }
        }
    }

    private func sync(from result: InstallFiltersResult?) {
        globalFiltersText = joined(result?.globalFilters ?? [])
        instanceFiltersText = joined(result?.instanceFilters ?? [])
        statusMessage = nil
    }

    private func hasChanges(from result: InstallFiltersResult) -> Bool {
        filters(from: globalFiltersText) != result.globalFilters
            || filters(from: instanceFiltersText) != result.instanceFilters
    }

    private func filters(from text: String) -> [String] {
        var seen = Set<String>()
        var values: [String] = []
        for line in text.split(whereSeparator: { $0.isNewline }) {
            let value = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else {
                continue
            }
            if seen.insert(value.lowercased()).inserted {
                values.append(value)
            }
        }
        return values
    }

    private func joined(_ filters: [String]) -> String {
        filters.joined(separator: "\n")
    }
}

