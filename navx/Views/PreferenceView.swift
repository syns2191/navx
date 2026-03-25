import SwiftUI

struct PreferenceView: View {
    @ObservedObject var shortcutManager: ShortcutManager
    @ObservedObject var workspaceManager: WorkspaceManager
    
    var body: some View {
        TabView {
            AppShortcutsView(shortcutManager: shortcutManager)
                .tabItem {
                    Label("App Shortcuts", systemImage: "app.badge")
                }
            
            WorkspacesSettingsView(workspaceManager: workspaceManager)
                .tabItem {
                    Label("Workspaces", systemImage: "macwindow.on.rectangle")
                }
        }
        .padding()
        .frame(width: 550, height: 500)
    }
}
