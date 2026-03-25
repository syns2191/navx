import SwiftUI

// MARK: - The Window Controller
class QuickAddPanelManager {
    static let shared = QuickAddPanelManager()
    
    // Remember to keep private(set) so the view can read its state!
    private(set) var panel: NSPanel?
    
    func showPanel(appName: String, windowElement: AXUIElement, bundleID: String?, appURL: URL?) {
        if panel == nil {
            panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 60),
                styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            // .screenSaver level forces it above EVERYTHING, even full-screen browser videos
            panel?.level = .screenSaver
            panel?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel?.titleVisibility = .hidden
            panel?.titlebarAppearsTransparent = true
            panel?.isMovableByWindowBackground = true
            
            // Critical for SwiftUI blurs to look correct
            panel?.backgroundColor = .clear
            panel?.isOpaque = false
        }
        
        let contentView = QuickAddPromptView(
            appName: appName,
            windowElement: windowElement,
            bundleID: bundleID,
            appURL: appURL,
            onClose: { [weak self] in
                // Fade out looks nicer than abruptly disappearing
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.2
                    self?.panel?.animator().alphaValue = 0
                }, completionHandler: {
                    self?.panel?.orderOut(nil)
                    self?.panel?.alphaValue = 1.0 // Reset for next time
                })
            }
        )
        
        // Force the frame size so SwiftUI doesn't accidentally collapse it to 0x0
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 450, height: 60)
        panel?.contentView = hostingView
        
        // Bulletproof Positioning (handles multiple monitors safely)
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let x = screen.visibleFrame.midX - 225 // Exactly centered horizontally
            let y = screen.visibleFrame.minY + 120 // 120px above the dock/bottom of screen
            panel?.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // THE MAGIC BULLET: Forces macOS to draw the panel even if Chrome is the active app
        panel?.orderFrontRegardless()
    }
}

// MARK: - The SwiftUI Row
struct QuickAddPromptView: View {
    var appName: String
    var windowElement: AXUIElement // The live reference to the window
    var bundleID: String?
    var appURL: URL?
    var onClose: () -> Void
    
    @ObservedObject var shortcutManager = ShortcutManager.shared
    @State private var isRecording = false
    @State private var localEventMonitor: Any?
    @State private var displayTitle = "Tracking Window..."
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Add shortcut for \(appName)?")
                    .font(.system(size: 13, weight: .bold))
                Text(displayTitle) // Shows dynamic title
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .onAppear {
                startTitlePolling() // Optional: Updates the UI while they navigate
            }
            
            Spacer()
            
            Button(isRecording ? "Listening..." : "Record Key") {
                recordKey()
            }
            .buttonStyle(.borderedProminent)
            .tint(isRecording ? .red : .blue)
            
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(VisualEffectView().ignoresSafeArea())
    }
    
    // Helper to get the absolute latest title directly from macOS
    private func getLiveTitle() -> String {
            var titleRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &titleRef)
            
            // 1. Try to get the title from our original element
            if result == .success, let title = titleRef as? String, !title.isEmpty {
                return title
            }
            
            // 2. BROWSER FALLBACK: If the element died or went stale during navigation,
            // we ask the OS for the app's currently focused window instead.
            if let bundleID = bundleID,
               let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
                
                let appElement = AXUIElementCreateApplication(app.processIdentifier)
                var focusedWindow: CFTypeRef?
                
                if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success {
                    let window = focusedWindow as! AXUIElement
                    var focusedTitle: CFTypeRef?
                    
                    if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &focusedTitle) == .success,
                       let fTitle = focusedTitle as? String, !fTitle.isEmpty {
                        return fTitle
                    }
                }
            }
            
            // Return empty string instead of "Unknown" so the timer ignores it
            // and keeps displaying the last known good title on the UI.
            return ""
        }
    
    // Optional: Keeps the UI updated if they are changing tabs
    private func startTitlePolling() {
            // Polling slightly faster (0.5s) feels snappier when typing URLs
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                if QuickAddPanelManager.shared.panel?.isVisible == false {
                    timer.invalidate()
                    return
                }
                
                let liveTitle = getLiveTitle()
                
                // Only update the UI if the title is actually valid.
                // This prevents it from flashing "Unknown" during page loads!
                if !liveTitle.isEmpty {
                    displayTitle = liveTitle
                }
            }
        }
    private func recordKey() {
        isRecording = true
        
        // FIX FOR LISTENER: Force navx to become the active app so it receives keystrokes
        NSApp.activate(ignoringOtherApps: true)
        
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let carbonKeyCode = UInt32(event.keyCode)
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            
            var display = ""
            if modifiers.contains(.control) { display += "⌃" }
            if modifiers.contains(.option) { display += "⌥" }
            if modifiers.contains(.shift) { display += "⇧" }
            if modifiers.contains(.command) { display += "⌘" }
            if let char = event.charactersIgnoringModifiers?.uppercased() { display += char }
            
            // FIX FOR CHROME: Grab the final title right as they press the key
            let finalTitle = getLiveTitle()
            
            let newShortcut = AppShortcut(
                id: UUID(),
                appName: "\(appName) - \(finalTitle)",
                bundleIdentifier: bundleID,
                targetKeyword: finalTitle, // Uses the final URL/Title
                appURL: appURL,
                displayKey: display,
                carbonKeyCode: carbonKeyCode,
                modifiersRawValue: modifiers.rawValue
            )
            
            shortcutManager.insertCompleteShortcut(newShortcut)
            
            isRecording = false
            if let monitor = localEventMonitor { NSEvent.removeMonitor(monitor) }
            onClose()
            return nil // Swallow the keystroke
        }
    }
}

// Helper for native blur background
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
