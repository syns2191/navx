import SwiftUI
import Combine
import Foundation
import AppKit
import ApplicationServices
import HotKey

// Represents a single, specific physical window
struct WindowContext: Identifiable {
    let id = UUID()
    let axWindow: AXUIElement // The C-level pointer to the window
    let bundleID: String
    let appName: String
}

// Represents the 4 workspaces for ONE specific monitor
struct ScreenWorkspaces {
    var currentIndex = 0
    var workspaces: [[WindowContext]] = [[], [], [], []]
}

class WorkspaceManager: ObservableObject {
    
    // Dictionary mapping a Monitor's unique ID to its own set of Workspaces
    @Published var monitors: [String: ScreenWorkspaces] = [:]
    
    private var hotKeys: [HotKey] = []
    
    init() {
        print("🖥️ Multi-Monitor Accessibility Manager started!")
        checkPermissions()
        setupVimNavigation()
    }
    
    // MARK: - 1. Security
    
    private func checkPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        if accessEnabled { print("✅ Accessibility permissions granted!") }
    }
    
    // MARK: - 2. Monitor Detection
    
    // Gets a unique ID for the screen your mouse/focus is currently on
    private func getActiveScreenID() -> String {
        guard let screen = NSScreen.main else { return "DefaultScreen" }
        return "\(screen.frame.origin.x)_\(screen.frame.origin.y)"
    }
    
    // Ensures the active monitor has its arrays set up
    private func ensureMonitorExists(id: String) {
        if monitors[id] == nil {
            monitors[id] = ScreenWorkspaces()
        }
    }
    
    // MARK: - 3. The Neovim Engine
    
    private func setupVimNavigation() {
        let markKey = HotKey(key: .n, modifiers: [.option])
        markKey.keyDownHandler = { self.assignActiveWindowToCurrentWorkspace() }
        hotKeys.append(markKey)
        
        let nextKey = HotKey(key: .j, modifiers: [.option])
        nextKey.keyDownHandler = { self.switchToWorkspace(direction: 1) }
        hotKeys.append(nextKey)
        
        let prevKey = HotKey(key: .k, modifiers: [.option])
        prevKey.keyDownHandler = { self.switchToWorkspace(direction: -1) }
        hotKeys.append(prevKey)
    }
    
    // MARK: - 4. Core Window Logic
    
    private func assignActiveWindowToCurrentWorkspace() {
        let screenID = getActiveScreenID()
        ensureMonitorExists(id: screenID)
        
        // 1. Get the C-level System Accessibility Object
        let systemWide = AXUIElementCreateSystemWide()
        var focusedAppRaw: CFTypeRef?
        var focusedWindowRaw: CFTypeRef?
        
        // 2. Drill down to the exact focused window
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppRaw) == .success,
              let focusedApp = focusedAppRaw as! AXUIElement?,
              AXUIElementCopyAttributeValue(focusedApp, kAXFocusedWindowAttribute as CFString, &focusedWindowRaw) == .success,
              let focusedWindow = focusedWindowRaw as! AXUIElement? else {
            print("❌ Failed to capture window. Is the Sandbox deleted?")
            return
        }
        
        // 3. Extract the Bundle ID so our UI can still show the Mac icons
        var pid: pid_t = 0
        AXUIElementGetPid(focusedApp, &pid)
        let app = NSRunningApplication(processIdentifier: pid)
        let bundleID = app?.bundleIdentifier ?? "unknown"
        let appName = app?.localizedName ?? "Unknown App"
        
        let windowContext = WindowContext(axWindow: focusedWindow, bundleID: bundleID, appName: appName)
        
        // 4. Save the window to THIS monitor's current workspace
        let currentIndex = monitors[screenID]!.currentIndex
        monitors[screenID]!.workspaces[currentIndex].append(windowContext)
        
        // Force UI update
        self.objectWillChange.send()
        print("📌 Assigned [\(appName)] Window to Monitor (\(screenID)) Workspace \(currentIndex + 1)")
    }
    
    private func switchToWorkspace(direction: Int) {
        let screenID = getActiveScreenID()
        ensureMonitorExists(id: screenID)
        
        var screenState = monitors[screenID]!
        let oldIndex = screenState.currentIndex
        
        // 1. Calculate new index
        var newIndex = oldIndex + direction
        if newIndex > 3 { newIndex = 0 }
        if newIndex < 0 { newIndex = 3 }
        
        // 2. Minimize all windows in the OLD workspace on THIS monitor
        for context in screenState.workspaces[oldIndex] {
            AXUIElementSetAttributeValue(context.axWindow, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        }
        
        // 3. Un-minimize (Raise) all windows in the NEW workspace on THIS monitor
        for context in screenState.workspaces[newIndex] {
            AXUIElementSetAttributeValue(context.axWindow, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        
        // 4. Update state
        screenState.currentIndex = newIndex
        monitors[screenID] = screenState
        
        print("🚀 Monitor (\(screenID)) switched to Workspace \(newIndex + 1)")
    }
}
