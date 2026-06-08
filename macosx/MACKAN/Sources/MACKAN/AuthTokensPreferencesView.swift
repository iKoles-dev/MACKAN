import AppKit
import SwiftUI

import MACKANKit

struct AuthTokensPreferencesView: View {
    @ObservedObject var model: AppModel
    @State private var host = ""
    @State private var token = ""
    @State private var selectedHost: String?
    @State private var isBusy = false
    @State private var statusMessage: String?

    var body: some View {
        PreferencesPaneScrollView {
            VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Authentication Tokens")
                    .font(.headline)

                Spacer()

                Button {
                    reloadTokens()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .disabled(isBusy)
            }

            List(model.authTokens, selection: $selectedHost) { authToken in
                HStack {
                    Text(authToken.host)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text(authToken.tokenPreview)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .tag(authToken.host as String?)
            }
            .frame(minHeight: 245)

            Form {
                TextField("Host", text: $host)
                SecureField("Token", text: $token)
            }

            if let statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button {
                    addToken()
                } label: {
                    Label("Add or Update", systemImage: "plus")
                }
                .disabled(isBusy || host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(role: .destructive) {
                    removeSelectedToken()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .disabled(isBusy || selectedHost == nil)

                Spacer()
            }
        }
        }
        .task {
            await loadTokens()
        }
        .alert("Authentication token update failed", isPresented: settingsErrorIsPresented) {
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

    private func loadTokens() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await model.loadAuthTokens()
            statusMessage = nil
        } catch {
            statusMessage = nil
        }
    }

    private func reloadTokens() {
        Task {
            await loadTokens()
        }
    }

    private func addToken() {
        Task {
            isBusy = true
            defer { isBusy = false }
            do {
                try await model.addAuthToken(host: host, token: token)
                selectedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
                self.host = ""
                token = ""
                statusMessage = "Authentication token saved."
            } catch {
                statusMessage = nil
            }
        }
    }

    private func removeSelectedToken() {
        guard let selectedHost else {
            return
        }
        Task {
            isBusy = true
            defer { isBusy = false }
            do {
                try await model.removeAuthToken(host: selectedHost)
                self.selectedHost = nil
                statusMessage = "Authentication token removed."
            } catch {
                statusMessage = nil
            }
        }
    }
}

