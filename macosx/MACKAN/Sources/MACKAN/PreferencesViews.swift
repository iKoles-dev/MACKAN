import AppKit
import SwiftUI

import MACKANKit

struct PreferencesView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView {
            GeneralPreferencesView(model: model)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            CompatibilityPreferencesView(model: model)
                .tabItem {
                    Label("Compatibility", systemImage: "checkmark.shield")
                }

            StabilityPreferencesView(model: model)
                .tabItem {
                    Label("Stability", systemImage: "slider.horizontal.3")
                }

            PreferredHostsPreferencesView(model: model)
                .tabItem {
                    Label("Hosts", systemImage: "network")
                }

            InstallFiltersPreferencesView(model: model)
                .tabItem {
                    Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                }

            LaunchCommandsPreferencesView(model: model)
                .tabItem {
                    Label("Launch", systemImage: "terminal")
                }

            AuthTokensPreferencesView(model: model)
                .tabItem {
                    Label("Auth", systemImage: "key")
                }

            PluginsPreferencesView()
                .tabItem {
                    Label("Plugins", systemImage: "puzzlepiece")
                }

            RepositoryPreferencesView(model: model)
                .tabItem {
                    Label("Repositories", systemImage: "tray.full")
                }

            CachePreferencesView(model: model)
                .tabItem {
                    Label("Cache", systemImage: "externaldrive")
                }
        }
        .frame(
            minWidth: CGFloat(PreferencesLayoutPolicy.minimumWidth),
            idealWidth: CGFloat(PreferencesLayoutPolicy.idealWidth),
            maxWidth: CGFloat(PreferencesLayoutPolicy.maximumWidth),
            minHeight: CGFloat(PreferencesLayoutPolicy.minimumHeight),
            idealHeight: CGFloat(PreferencesLayoutPolicy.idealHeight),
            maxHeight: .infinity)
    }
}

struct PreferencesPaneScrollView<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding()
        }
    }
}

