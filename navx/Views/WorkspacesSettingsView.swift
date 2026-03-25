import SwiftUI
import AppKit

struct WorkspacesSettingsView: View {
    @ObservedObject var workspaceManager: WorkspaceManager
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Workspaces")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Press ⌥N to assign an active app. Use ⌥J and ⌥K to navigate.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
            
            // MARK: - Workspace Cards
            
        }
    }
}

// MARK: - The Individual Workspace Card



// MARK: - The App Icon Component

struct AppIconBadge: View {
    var bundleID: String
    var onDelete: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                // Fetch the real Mac icon
                Image(nsImage: getIcon(for: bundleID))
                    .resizable()
                    .frame(width: 40, height: 40)
                
                // The tiny 'X' button that appears on hover
                if isHovering {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white, .red)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 4, y: -4)
                }
            }
            
            // App Name
            Text(getName(for: bundleID))
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .frame(width: 60)
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    // Translates "com.google.Chrome" into "Google Chrome" and gets the icon
    private func getIcon(for bundleID: String) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil)!
    }
    
    private func getName(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return url.deletingPathExtension().lastPathComponent
        }
        return "Unknown"
    }
}
