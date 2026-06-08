import AppKit
import SwiftUI

import MACKANKit

struct PreferredHostsPreferencesView: View {
    @ObservedObject var model: AppModel
    @State private var draftPreferredHosts: [String?] = []
    @State private var selectedAvailableHost: String?
    @State private var selectedPreferredIndex: Int?
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
                        reloadHosts()
                    } label: {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }
                    .disabled(isBusy)
                }

                if let result = model.preferredHosts {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Available hosts")
                                .font(.headline)
                            List(availableDraftHosts, id: \.self, selection: $selectedAvailableHost) { host in
                                Text(host)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .frame(minHeight: 260)
                        }

                        VStack(spacing: 8) {
                            Button {
                                addSelectedHost()
                            } label: {
                                Label("Add", systemImage: "arrow.right")
                            }
                            .disabled(isBusy || selectedAvailableHost == nil)

                            Button {
                                removeSelectedHost()
                            } label: {
                                Label("Remove", systemImage: "arrow.left")
                            }
                            .disabled(isBusy || !canRemoveSelectedPreferredHost)

                            Divider()

                            Button {
                                moveSelectedPreferredHost(up: true)
                            } label: {
                                Label("Higher", systemImage: "arrow.up")
                            }
                            .disabled(isBusy || selectedPreferredIndex == nil || selectedPreferredIndex == 0)

                            Button {
                                moveSelectedPreferredHost(up: false)
                            } label: {
                                Label("Lower", systemImage: "arrow.down")
                            }
                            .disabled(isBusy || !canMoveSelectedPreferredHostDown)
                        }
                        .frame(width: 120)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Preferred hosts")
                                .font(.headline)
                            List(selection: $selectedPreferredIndex) {
                                ForEach(draftPreferredHosts.indices, id: \.self) { index in
                                    preferredHostLabel(for: draftPreferredHosts[index])
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .tag(index as Int?)
                                }
                            }
                            .frame(minHeight: 260)
                        }
                    }

                    if let statusMessage {
                        Label(statusMessage, systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(result.placeholderLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button(role: .destructive) {
                            clearPreferredHosts()
                        } label: {
                            Label("Clear", systemImage: "xmark.circle")
                        }
                        .disabled(isBusy || draftPreferredHosts.isEmpty)

                        Button {
                            savePreferredHosts()
                        } label: {
                            Label("Save", systemImage: "checkmark")
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(isBusy || draftPreferredHosts == result.preferredHosts)
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
            await loadHosts()
        }
        .onChange(of: model.selectedInstanceID) { _ in
            Task {
                await loadHosts()
            }
        }
        .onChange(of: model.preferredHosts) { result in
            sync(from: result)
        }
        .alert("Preferred hosts update failed", isPresented: settingsErrorIsPresented) {
            Button("OK", role: .cancel) {
                model.clearSettingsError()
            }
        } message: {
            Text(model.settingsError ?? "")
        }
    }

    private var availableDraftHosts: [String] {
        guard let result = model.preferredHosts else {
            return []
        }
        return result.availableHosts.filter { availableHost in
            !draftPreferredHosts.contains { preferredHost in
                preferredHost?.localizedCaseInsensitiveCompare(availableHost) == .orderedSame
            }
        }
    }

    private var canRemoveSelectedPreferredHost: Bool {
        guard let selectedPreferredIndex,
              draftPreferredHosts.indices.contains(selectedPreferredIndex)
        else {
            return false
        }
        return draftPreferredHosts[selectedPreferredIndex] != nil
    }

    private var canMoveSelectedPreferredHostDown: Bool {
        guard let selectedPreferredIndex else {
            return false
        }
        return selectedPreferredIndex < draftPreferredHosts.count - 1
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

    private func preferredHostLabel(for host: String?) -> some View {
        HStack(spacing: 6) {
            if host == nil {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }
            Text(host ?? model.preferredHosts?.placeholderLabel ?? "<ALL OTHER HOSTS>")
                .foregroundStyle(host == nil ? .secondary : .primary)
        }
    }

    private func loadHosts() async {
        guard model.selectedInstance != nil else {
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            try await model.loadPreferredHosts()
            statusMessage = nil
        } catch {
            statusMessage = nil
        }
    }

    private func reloadHosts() {
        Task {
            await loadHosts()
        }
    }

    private func addSelectedHost() {
        guard let selectedAvailableHost else {
            return
        }
        if draftPreferredHosts.contains(where: {
            $0?.localizedCaseInsensitiveCompare(selectedAvailableHost) == .orderedSame
        }) {
            return
        }

        if let placeholderIndex = draftPreferredHosts.firstIndex(where: { $0 == nil }) {
            draftPreferredHosts.insert(selectedAvailableHost, at: placeholderIndex)
            selectedPreferredIndex = placeholderIndex
        } else {
            draftPreferredHosts.append(selectedAvailableHost)
            draftPreferredHosts.append(nil)
            selectedPreferredIndex = draftPreferredHosts.count - 2
        }
        self.selectedAvailableHost = nil
        statusMessage = nil
    }

    private func removeSelectedHost() {
        guard canRemoveSelectedPreferredHost,
              let selectedPreferredIndex
        else {
            return
        }
        draftPreferredHosts.remove(at: selectedPreferredIndex)
        if draftPreferredHosts.count == 1 && draftPreferredHosts[0] == nil {
            draftPreferredHosts.removeAll()
            self.selectedPreferredIndex = nil
        } else if draftPreferredHosts.indices.contains(selectedPreferredIndex) {
            self.selectedPreferredIndex = selectedPreferredIndex
        } else {
            self.selectedPreferredIndex = draftPreferredHosts.indices.last
        }
        statusMessage = nil
    }

    private func moveSelectedPreferredHost(up: Bool) {
        guard let selectedPreferredIndex else {
            return
        }
        let destination = up ? selectedPreferredIndex - 1 : selectedPreferredIndex + 1
        guard draftPreferredHosts.indices.contains(destination) else {
            return
        }
        draftPreferredHosts.swapAt(selectedPreferredIndex, destination)
        self.selectedPreferredIndex = destination
        statusMessage = nil
    }

    private func clearPreferredHosts() {
        draftPreferredHosts = []
        selectedPreferredIndex = nil
        statusMessage = nil
    }

    private func savePreferredHosts() {
        Task {
            isBusy = true
            defer { isBusy = false }
            do {
                try await model.updatePreferredHosts(draftPreferredHosts)
                statusMessage = "Preferred hosts saved."
            } catch {
                statusMessage = nil
            }
        }
    }

    private func sync(from result: PreferredHostsResult?) {
        draftPreferredHosts = result?.preferredHosts ?? []
        selectedAvailableHost = nil
        selectedPreferredIndex = nil
    }
}

