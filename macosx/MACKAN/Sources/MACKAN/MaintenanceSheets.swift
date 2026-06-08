import AppKit
import SwiftUI

import MACKANKit

struct UnmanagedFilesSheet: View {
    let result: UnmanagedFilesResult?
    let onRevealFile: (UnmanagedFileSummary) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Unmanaged Files")
                    .font(.headline)
                Spacer()
                Button("Close", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }

            if let result {
                Text(summaryText(result))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if result.files.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 34))
                            .foregroundStyle(.green)
                        Text("No unmanaged files")
                            .font(.headline)
                    }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Table(result.files) {
                        TableColumn("Type") { file in
                            Text(file.kind.uppercased())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .width(70)
                        TableColumn("Identifier", value: \.identifier)
                        TableColumn("Version") { file in
                            Text(file.version ?? "-")
                                .foregroundStyle(file.version == nil ? .secondary : .primary)
                        }
                        .width(min: 120, ideal: 160)
                        TableColumn("Path") { file in
                            Text(file.path ?? "-")
                                .foregroundStyle(file.path == nil ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        TableColumn("Reveal") { file in
                            Button {
                                onRevealFile(file)
                            } label: {
                                Image(systemName: "folder")
                            }
                            .buttonStyle(.borderless)
                            .help("Show in Finder")
                            .accessibilityLabel("Show \(file.identifier) in Finder")
                            .disabled(file.path?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                        }
                        .width(70)
                    }
                }
            }
        }
        .padding()
        .mackanModalSheetFrame(.standard)
    }

    private func summaryText(_ result: UnmanagedFilesResult) -> String {
        let changeText = result.changed ? "Registry updated" : "Registry unchanged"
        return "\(changeText) - \(result.files.count.formatted()) detected"
    }
}

struct InstallationHistorySheet: View {
    let result: InstallationHistoryResult?
    let onInstallMissing: ([InstallationHistoryModule]) -> Void
    let onRestoreExactVersions: ([InstallationHistoryModule]) -> Void
    let onClose: () -> Void
    @State private var selectedEntryID: InstallationHistoryEntry.ID?

    private var selectedEntry: InstallationHistoryEntry? {
        guard let result else {
            return nil
        }
        return result.entries.first { $0.id == selectedEntryID } ?? result.entries.first
    }

    private var missingInstallableModules: [InstallationHistoryModule] {
        selectedEntry?.modules.filter { !$0.isInstalled && $0.isAvailable } ?? []
    }

    private var exactRestorableModules: [InstallationHistoryModule] {
        missingInstallableModules.filter { module in
            !(module.version?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Installation History")
                    .font(.headline)
                Spacer()
                Button("Close", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }

            if let result {
                if result.entries.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "clock")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("No installation history")
                            .font(.headline)
                    }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        List(result.entries, selection: $selectedEntryID) { entry in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(displayDate(entry.savedAt))
                                    .font(.callout)
                                    .lineLimit(1)
                                Text("\(entry.modules.count.formatted()) mods")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .tag(entry.id)
                        }
                        .frame(minHeight: 120, idealHeight: 160, maxHeight: 190)

                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(selectedEntry.map { displayDate($0.savedAt) } ?? "")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(selectedEntry?.fileName ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                HStack(spacing: 8) {
                                    Button {
                                        onRestoreExactVersions(exactRestorableModules)
                                    } label: {
                                        Label("Restore Exact Versions", systemImage: "clock.arrow.circlepath")
                                    }
                                    .disabled(exactRestorableModules.isEmpty)

                                    Button {
                                        onInstallMissing(missingInstallableModules)
                                    } label: {
                                        Label("Install Missing", systemImage: "plus.circle")
                                    }
                                    .disabled(missingInstallableModules.isEmpty)
                                }
                            }

                            if let entry = selectedEntry {
                                Table(entry.modules) {
                                    TableColumn("Status") { module in
                                        Text(module.historyStatusTitle)
                                            .foregroundStyle(module.historyStatusColor)
                                    }
                                    .width(95)
                                    TableColumn("Mod") { module in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(module.name)
                                                .lineLimit(1)
                                            Text(module.identifier)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    TableColumn("Version") { module in
                                        Text(module.version ?? "-")
                                            .foregroundStyle(module.version == nil ? .secondary : .primary)
                                    }
                                    .width(110)
                                    TableColumn("Author") { module in
                                        Text(module.author ?? "-")
                                            .foregroundStyle(module.author == nil ? .secondary : .primary)
                                            .lineLimit(1)
                                    }
                                    .width(min: 120, ideal: 160)
                                    TableColumn("Description") { module in
                                        Text(module.abstract ?? "-")
                                            .foregroundStyle(module.abstract == nil ? .secondary : .primary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .padding(.top, 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .padding()
        .mackanModalSheetFrame(.wide)
        .onAppear {
            selectedEntryID = selectedEntryID ?? result?.entries.first?.id
        }
    }

    private func displayDate(_ savedAt: String) -> String {
        if let date = Self.historyDateFormatter.date(from: savedAt) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return savedAt
    }

    private static let historyDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

struct PlayTimeSheet: View {
    let result: PlayTimeResult?
    let onSave: (String, Double) async -> Void
    let onClose: () -> Void
    @State private var editedHours: [String: String] = [:]
    @State private var savingInstanceID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Play Time")
                    .font(.headline)
                Spacer()
                if let result {
                    Text("Total \(result.totalDisplay) h")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button("Close", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }

            if let result {
                if result.entries.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "clock")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("No play time")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(result.entries) { entry in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.name)
                                    .font(.callout)
                                    .lineLimit(1)
                                Text(entry.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            TextField(
                                "Hours",
                                text: Binding(
                                    get: { editedHours[entry.instanceId] ?? entry.display },
                                    set: { editedHours[entry.instanceId] = $0 }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)

                            Text("h")
                                .foregroundStyle(.secondary)

                            Button {
                                save(entry)
                            } label: {
                                Label("Save", systemImage: "checkmark")
                            }
                            .disabled(!canSave(entry) || savingInstanceID != nil)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .mackanModalSheetFrame(.standard)
        .onAppear {
            seedEdits(result)
        }
        .onChange(of: result) { newResult in
            seedEdits(newResult)
        }
    }

    private func seedEdits(_ result: PlayTimeResult?) {
        editedHours = Dictionary(
            uniqueKeysWithValues: result?.entries.map { ($0.instanceId, $0.display) } ?? [])
    }

    private func canSave(_ entry: PlayTimeEntry) -> Bool {
        guard let hours = parsedHours(for: entry) else {
            return false
        }
        return abs(hours - entry.hours) > 0.0001
    }

    private func save(_ entry: PlayTimeEntry) {
        guard let hours = parsedHours(for: entry) else {
            return
        }
        Task {
            savingInstanceID = entry.instanceId
            defer { savingInstanceID = nil }
            await onSave(entry.instanceId, hours)
        }
    }

    private func parsedHours(for entry: PlayTimeEntry) -> Double? {
        let raw = (editedHours[entry.instanceId] ?? entry.display)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let hours = Double(raw), hours >= 0, hours.isFinite else {
            return nil
        }
        return hours
    }
}

struct DownloadStatisticsSheet: View {
    let result: DownloadStatisticsResult?
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Download Statistics")
                    .font(.headline)
                Spacer()
                if let result {
                    Text("Cached \(result.totalDisplay)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button("Close", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }

            if let result {
                if result.hosts.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "chart.pie")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("No cached downloads")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        DownloadStatisticsChartView(segments: DownloadStatisticsChartSegment.segments(for: result))

                        Table(result.hosts) {
                            TableColumn("Host") { host in
                                Text(host.host)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            TableColumn("Cached Size") { host in
                                Text(host.display)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .width(120)
                            TableColumn("Share") { host in
                                HStack(spacing: 8) {
                                    ProgressView(value: host.share(of: result.totalBytes))
                                        .frame(width: 120)
                                    Text(host.shareDisplay(of: result.totalBytes))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 54, alignment: .trailing)
                                }
                            }
                            .width(200)
                            TableColumn("Support") { host in
                                if let url = host.donationURL {
                                    Link(destination: url) {
                                        Label("Donate", systemImage: "heart")
                                    }
                                } else {
                                    Text("-")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .width(110)
                        }
                    }
                }
            }
        }
        .padding()
        .mackanModalSheetFrame(.standard)
    }
}

private struct DownloadStatisticsChartView: View {
    let segments: [DownloadStatisticsChartSegment]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Self.color(for: index))
                            .frame(width: max(2, proxy.size.width * segment.fraction))
                            .accessibilityLabel("\(segment.host), \(percentDisplay(segment.fraction)) of cached downloads")
                    }
                }
            }
            .frame(height: 18)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], alignment: .leading, spacing: 6) {
                ForEach(Array(segments.prefix(6).enumerated()), id: \.element.id) { index, segment in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Self.color(for: index))
                            .frame(width: 10, height: 10)
                        Text(segment.host)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 6)
                        Text("\(segment.display) (\(percentDisplay(segment.fraction)))")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .font(.caption)
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private static func color(for index: Int) -> Color {
        let palette: [Color] = [
            .blue,
            .green,
            .orange,
            .pink,
            .teal,
            .indigo,
            .red,
            .mint,
        ]
        return palette[index % palette.count]
    }

    private func percentDisplay(_ fraction: Double) -> String {
        let percent = fraction * 100
        return "\(percent.formatted(.number.precision(.fractionLength(0...1))))%"
    }
}

private extension DownloadStatisticsHost {
    func share(of totalBytes: Int64) -> Double {
        guard totalBytes > 0 else {
            return 0
        }
        return Double(bytes) / Double(totalBytes)
    }

    func shareDisplay(of totalBytes: Int64) -> String {
        let percent = share(of: totalBytes) * 100
        return "\(percent.formatted(.number.precision(.fractionLength(0...1))))%"
    }
}

struct CacheMaintenanceSheet: View {
    let info: CacheInfoResult?
    let purgeResult: CachePurgeResult?
    let onRefresh: () async -> Void
    let onPurgeToLimit: () async -> Void
    let onPurgeAll: () async -> Void
    let onClose: () -> Void
    @State private var isWorking = false
    @State private var isConfirmingPurgeAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Download Cache")
                    .font(.headline)
                Spacer()
                Button("Close", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }

            if let info {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    cacheRow("Location", info.path, monospaced: true)
                    cacheRow("Files", info.fileCount.formatted())
                    cacheRow("Size", info.display)
                    cacheRow("Free Space", info.freeDisplay ?? "Unknown")
                    cacheRow("Limit", info.limitDisplay ?? "Unlimited")
                }

                if let purgeResult {
                    HStack(spacing: 8) {
                        Image(systemName: purgeResult.purgedBytes > 0 ? "checkmark.circle" : "info.circle")
                            .foregroundStyle(purgeResult.purgedBytes > 0 ? .green : .secondary)
                        Text(purgeSummary(purgeResult))
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }

                Spacer()

                HStack {
                    Button {
                        NSWorkspace.shared.open(URL(fileURLWithPath: info.path))
                    } label: {
                        Label("Open in Finder", systemImage: "folder")
                    }
                    Button {
                        run(onRefresh)
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(isWorking)
                    MackanSettingsButton {
                        Label("Edit Settings", systemImage: "gearshape")
                    }
                    Spacer()
                    Button {
                        run(onPurgeToLimit)
                    } label: {
                        Label("Purge to Limit", systemImage: "scalemass")
                    }
                    .disabled(isWorking || !info.isOverLimit)
                    Button(role: .destructive) {
                        isConfirmingPurgeAll = true
                    } label: {
                        Label("Purge All", systemImage: "trash")
                    }
                    .disabled(isWorking || info.fileCount == 0)
                }
            }
        }
        .padding()
        .mackanModalSheetFrame(.standard)
        .confirmationDialog("Purge all cached downloads?", isPresented: $isConfirmingPurgeAll) {
            Button("Purge All", role: .destructive) {
                run(onPurgeAll)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmPurgeText)
        }
    }

    private func cacheRow(_ title: String, _ value: String, monospaced: Bool = false) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .font(monospaced ? .system(.body, design: .monospaced) : .body)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var confirmPurgeText: String {
        guard let info else {
            return ""
        }
        return "Delete \(info.fileCount.formatted()) cached files and free \(info.display)."
    }

    private func purgeSummary(_ result: CachePurgeResult) -> String {
        let action = result.mode == "limit" ? "Purged to limit" : "Purged cache"
        return "\(action): \(result.purgedFileCount.formatted()) files, \(result.purgedDisplay)."
    }

    private func run(_ action: @escaping () async -> Void) {
        Task {
            isWorking = true
            defer { isWorking = false }
            await action()
        }
    }
}

struct DeduplicateResultSheet: View {
    let result: DeduplicateResult?
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Deduplicate Installed Files")
                    .font(.headline)
                Spacer()
                if let result {
                    Label(result.statusTitle, systemImage: result.statusSymbolName)
                        .foregroundStyle(result.statusColor)
                }
            }

            if let error = result?.error, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
            }

            if let result {
                if result.events.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: result.statusSymbolName)
                            .font(.system(size: 34))
                            .foregroundStyle(result.statusColor)
                        Text(result.statusTitle)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(Array(result.events.enumerated()), id: \.offset) { _, event in
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
                }
            }

            HStack {
                Spacer()
                Button("Close", role: .cancel, action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .mackanModalSheetFrame(.standard)
    }
}

struct RepairRegistryResultSheet: View {
    let result: RepairRegistryResult?
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Repair Registry")
                        .font(.headline)
                    if let instanceId = result?.instanceId, !instanceId.isEmpty {
                        Text(instanceId)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let result {
                    Label(result.statusTitle, systemImage: result.statusSymbolName)
                        .foregroundStyle(result.statusColor)
                }
            }

            if let error = result?.error, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
            }

            if let result {
                if result.events.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: result.statusSymbolName)
                            .font(.system(size: 34))
                            .foregroundStyle(result.statusColor)
                        Text(result.statusTitle)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(Array(result.events.enumerated()), id: \.offset) { _, event in
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
                }
            }

            HStack {
                Spacer()
                Button("Close", role: .cancel, action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .mackanModalSheetFrame(.standard)
    }
}

private extension DeduplicateResult {
    var statusTitle: String {
        switch status {
        case "completed":
            return "Completed"
        case "cancelled":
            return "Cancelled"
        case "failed":
            return "Failed"
        default:
            return status.capitalized
        }
    }

    var statusSymbolName: String {
        switch status {
        case "completed":
            return "checkmark.circle.fill"
        case "cancelled":
            return "xmark.circle.fill"
        case "failed":
            return "exclamationmark.triangle.fill"
        default:
            return "circle"
        }
    }

    var statusColor: Color {
        switch status {
        case "completed":
            return .green
        case "cancelled":
            return .secondary
        case "failed":
            return .orange
        default:
            return .secondary
        }
    }
}

private extension RepairRegistryResult {
    var statusTitle: String {
        switch status {
        case "completed":
            return "Completed"
        case "cancelled":
            return "Cancelled"
        case "failed":
            return "Failed"
        default:
            return status.capitalized
        }
    }

    var statusSymbolName: String {
        switch status {
        case "completed":
            return "checkmark.circle.fill"
        case "cancelled":
            return "xmark.circle.fill"
        case "failed":
            return "exclamationmark.triangle.fill"
        default:
            return "circle"
        }
    }

    var statusColor: Color {
        switch status {
        case "completed":
            return .green
        case "cancelled":
            return .secondary
        case "failed":
            return .orange
        default:
            return .secondary
        }
    }
}

private extension InstallationHistoryModule {
    var historyStatusTitle: String {
        if isInstalled {
            return "Installed"
        }
        return isAvailable ? "Available" : "Unavailable"
    }

    var historyStatusColor: Color {
        if isInstalled {
            return .green
        }
        return isAvailable ? .blue : .secondary
    }
}
