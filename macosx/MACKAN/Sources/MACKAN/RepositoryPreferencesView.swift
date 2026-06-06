import AppKit
import SwiftUI

import MACKANKit

struct RepositoryPreferencesView: View {
    @ObservedObject var model: AppModel
    @State private var selectedRepositoryID: RepositorySummary.ID?
    @State private var isAddingRepository = false
    @State private var newRepositoryName = ""
    @State private var newRepositoryURL = ""
    @State private var errorMessage: String?
    @State private var isBusy = false

    var body: some View {
        VStack(spacing: 12) {
            Table(model.repositoryManagementRows, selection: $selectedRepositoryID) {
                TableColumn("Priority") { row in
                    Text(row.priority.formatted())
                        .monospacedDigit()
                }
                .width(70)

                TableColumn("Name", value: \.name)
                    .width(min: 120, ideal: 160)

                TableColumn("URL", value: \.url)

                TableColumn("Mirror") { row in
                    Image(systemName: row.isMirror ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(row.isMirror ? .green : .secondary)
                }
                .width(70)
            }

            if let repositoryRefreshText {
                HStack(spacing: 6) {
                    if model.repositoryRefreshSummary?.isActive == true {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                    Text(repositoryRefreshText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            if let summary = model.repositoryRefreshSummary, !summary.events.isEmpty {
                List(Array(summary.events.enumerated()), id: \.offset) { _, event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.kindTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let percent = event.percent {
                                Text("\(percent)%")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        Text(event.message)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 3)
                }
                .listStyle(.inset)
                .frame(minHeight: 90, maxHeight: 150)
            }

            if let summary = model.repositoryRefreshSummary,
               summary.errorDetails?.isDownloadFailure == true {
                DownloadFailureNotice(
                    message: summary.error,
                    failures: summary.errorDetails?.downloadFailures ?? [],
                    onRetry: {
                        refreshRepositories()
                    },
                    canSkipDownloadFailuresRetry: false,
                    onSkipDownloadFailuresRetry: {})
            }

            HStack {
                Button {
                    refreshRepositories()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isBusy || repositoryRefreshIsActive)

                if repositoryRefreshIsActive {
                    Button(role: .destructive) {
                        cancelRepositoryRefresh()
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle")
                    }
                    .disabled(isBusy)
                }

                Spacer()

                Button {
                    moveSelectedRepository(by: -1)
                } label: {
                    Label("Move Up", systemImage: "arrow.up")
                }
                .disabled(isBusy || selectedRepository?.canMoveUp != true)

                Button {
                    moveSelectedRepository(by: 1)
                } label: {
                    Label("Move Down", systemImage: "arrow.down")
                }
                .disabled(isBusy || selectedRepository?.canMoveDown != true)

                Button {
                    beginAddingRepository()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .disabled(isBusy)

                Button {
                    removeSelectedRepository()
                } label: {
                    Label("Remove", systemImage: "minus")
                }
                .disabled(isBusy || selectedRepository?.canRemove != true)
            }
        }
        .padding()
        .sheet(isPresented: $isAddingRepository) {
            AddRepositorySheet(
                name: $newRepositoryName,
                url: $newRepositoryURL,
                availableRepositories: model.availableRepositories,
                isBusy: isBusy,
                onCancel: {
                    isAddingRepository = false
                },
                onAdd: addRepository)
        }
        .alert("Repository update failed", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var selectedRepository: RepositoryManagementRow? {
        model.repositoryManagementRows.first { $0.id == selectedRepositoryID }
    }

    private var repositoryRefreshIsActive: Bool {
        model.repositoryRefreshSummary?.isActive == true
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

    private var repositoryRefreshText: String? {
        guard let summary = model.repositoryRefreshSummary else {
            return nil
        }

        switch summary.operationStatus {
        case "running":
            return "Refreshing repositories..."
        case "cancelling":
            return "Cancelling repository refresh..."
        default:
            break
        }

        let status = switch summary.status {
        case "updated":
            "Updated"
        case "noChanges":
            "Up to date"
        case "outdatedClient":
            "CKAN update required"
        default:
            "Refresh failed"
        }
        return "\(status) - \(summary.compatibleModuleCount.formatted()) compatible modules"
    }

    private func beginAddingRepository() {
        newRepositoryName = ""
        newRepositoryURL = ""
        isAddingRepository = true
        Task {
            do {
                try await model.loadAvailableRepositories()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func refreshRepositories() {
        Task {
            isBusy = true
            defer { isBusy = false }
            do {
                try await model.refreshRepositories()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func cancelRepositoryRefresh() {
        Task {
            do {
                try await model.cancelRepositoryRefresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func addRepository() {
        let name = newRepositoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = newRepositoryURL.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            isBusy = true
            defer { isBusy = false }
            do {
                try await model.addRepository(name: name, url: url)
                selectedRepositoryID = name
                isAddingRepository = false
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func removeSelectedRepository() {
        guard let selectedRepository else { return }
        Task {
            isBusy = true
            defer { isBusy = false }
            do {
                try await model.removeRepository(name: selectedRepository.name)
                selectedRepositoryID = model.repositoryManagementRows.first?.id
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func moveSelectedRepository(by delta: Int) {
        guard let selectedRepository else { return }
        let priority = selectedRepository.priority + delta
        Task {
            isBusy = true
            defer { isBusy = false }
            do {
                try await model.setRepositoryPriority(name: selectedRepository.name, priority: priority)
                selectedRepositoryID = selectedRepository.id
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct AddRepositorySheet: View {
    @Binding var name: String
    @Binding var url: String
    let availableRepositories: [RepositorySummary]
    let isBusy: Bool
    let onCancel: () -> Void
    let onAdd: () -> Void
    @State private var selectedRepositoryID: RepositorySummary.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Repository")
                .font(.headline)

            if !availableRepositories.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Known Sources")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Name")
                                .frame(width: 160, alignment: .leading)
                            Text("URL")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)

                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(availableRepositories) { repository in
                                    Button {
                                        selectKnownRepository(repository)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Text(repository.name)
                                                .frame(width: 160, alignment: .leading)
                                            Text(repository.url)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .contentShape(Rectangle())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(knownRepositoryRowBackground(repository))
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(height: CGFloat(AddRepositorySheetPresentationPolicy.knownSourcesHeight))
                    }
                }
            }

            Form {
                TextField("Name", text: $name)
                TextField("URL", text: $url)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Add", action: onAdd)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isBusy || !canAdd)
            }
        }
        .padding()
        .frame(minHeight: CGFloat(AddRepositorySheetPresentationPolicy.minimumSheetHeight))
        .mackanModalSheetFrame(.standard)
    }

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func selectKnownRepository(_ repository: RepositorySummary) {
        selectedRepositoryID = repository.id
        if let fields = AddRepositorySheetPresentationPolicy.fields(
            for: repository.id,
            in: availableRepositories)
        {
            name = fields.name
            url = fields.url
        }
    }

    private func knownRepositoryRowBackground(_ repository: RepositorySummary) -> some ShapeStyle {
        repository.id == selectedRepositoryID
            ? AnyShapeStyle(Color.accentColor.opacity(0.22))
            : AnyShapeStyle(Color.clear)
    }
}
