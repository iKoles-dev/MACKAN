import AppKit
import SwiftUI

import MACKANKit

struct LaunchWarningSheet: View {
    let warning: PendingLaunchWarning
    let isLaunching: Bool
    let onCancel: () -> Void
    let onLaunch: (Bool) -> Void
    @State private var suppressFutureWarnings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Incompatible Mods Installed")
                        .font(.headline)
                    Text("Launching now may make the game unstable.")
                        .foregroundStyle(.secondary)
                }
            }

            Table(warning.modules) {
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
                TableColumn("Installed", value: \.version)
                    .width(90)
                TableColumn("Compatible With", value: \.compatibleGameVersions)
                    .width(min: 150, ideal: 190)
            }

            Toggle("Don't show this again for these mods", isOn: $suppressFutureWarnings)

            HStack {
                Spacer()
                Button("Go Back", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button {
                    onLaunch(suppressFutureWarnings)
                } label: {
                    Label("Launch Anyway", systemImage: "play.fill")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isLaunching)
            }
        }
        .padding()
        .mackanModalSheetFrame(.standard)
    }
}

struct InspectorView: View {
    let module: ModuleSummary?
    let details: ModuleDetails?
    let stagedAction: StagedModAction?
    let emptyState: InspectorEmptyPresentationState
    @State private var selectedSection: ModuleInspectorSection = .overview

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let module {
                let matchingDetails = details?.belongs(to: module) == true ? details : nil
                let displayModule = matchingDetails?.module ?? module
                ModuleDetailHeader(module: displayModule, details: matchingDetails, stagedAction: stagedAction)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Picker("Module details section", selection: $selectedSection) {
                        ForEach(ModuleInspectorSection.allCases) { section in
                            Text(section.title)
                                .tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.small)
                    .accessibilityLabel("Module details section")
                    .accessibilityValue(selectedSection.accessibilityTitle)

                    ModuleInspectorSectionContent(
                        section: selectedSection,
                        module: displayModule,
                        details: matchingDetails,
                        stagedAction: stagedAction)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.secondary.opacity(0.08))
                            .frame(width: 72, height: 72)
                        Image(systemName: emptyState.systemImage)
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.secondary.opacity(0.6), Color.secondary.opacity(0.35)],
                                    startPoint: .top,
                                    endPoint: .bottom))
                    }
                    VStack(spacing: 5) {
                        Text(emptyState.title)
                            .font(.headline)
                        Text(emptyState.detail)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 280)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private extension ModuleDetails {
    func belongs(to module: ModuleSummary) -> Bool {
        self.module.identifier.localizedCaseInsensitiveCompare(module.identifier) == .orderedSame
    }
}

private enum ModuleInspectorSection: String, CaseIterable, Identifiable {
    case overview
    case relationships
    case versions
    case contents
    case resources

    var id: Self { self }

    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .relationships:
            return "Relations"
        case .versions:
            return "Versions"
        case .contents:
            return "Files"
        case .resources:
            return "Links"
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .overview:
            return "Overview"
        case .relationships:
            return "Relationships"
        case .versions:
            return "Versions"
        case .contents:
            return "Contents"
        case .resources:
            return "Resources"
        }
    }
}

private struct ModuleInspectorSectionContent: View {
    let section: ModuleInspectorSection
    let module: ModuleSummary
    let details: ModuleDetails?
    let stagedAction: StagedModAction?

    var body: some View {
        switch section {
        case .overview:
            ModuleOverviewPage(module: module, details: details, stagedAction: stagedAction)
        case .relationships:
            RelationshipGraphView(graph: ModuleRelationshipGraph(module: module))
        case .versions:
            ModuleVersionsView(module: module)
        case .contents:
            ModuleContentsView(paths: module.contents)
        case .resources:
            ModuleResourcesView(resources: details?.resources ?? [])
        }
    }
}
