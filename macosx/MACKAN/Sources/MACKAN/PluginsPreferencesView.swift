import AppKit
import SwiftUI

import MACKANKit

struct PluginsPreferencesView: View {
    private let supportState = PluginRuntimeSupportState.nativeMacOS

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Plugins")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                Label(supportState.title, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                Text(supportState.explanation)
                    .foregroundStyle(.secondary)

                Divider()

                Text("Planned path")
                    .font(.headline)
                Text(supportState.plannedPath)
                    .foregroundStyle(.secondary)

                Divider()

                HStack(spacing: 12) {
                    ForEach(supportState.links) { link in
                        Link(link.title, destination: link.url)
                    }
                }
                .font(.callout)
            }
        }
        .padding()
        .frame(minWidth: 300, maxWidth: .infinity, alignment: .topLeading)
    }
}
