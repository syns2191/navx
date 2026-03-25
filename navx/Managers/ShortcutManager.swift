//
//  ShortcutManager.swift
//  navx
//
//  Created by Syns G on 23/02/26.
//

import SwiftUI
import Combine
import AppKit
import ApplicationServices
import HotKey

// MARK: - Models
struct AppShortcut: Identifiable, Codable {
    var id = UUID()
    var appName: String
    var bundleIdentifier: String?
    var targetKeyword: String?    // Stores the specific window title suffix
    var appURL: URL?
    var displayKey: String
    var carbonKeyCode: UInt32
    
    var modifiersRawValue: UInt
    var modifiers: NSEvent.ModifierFlags {
        return NSEvent.ModifierFlags(rawValue: modifiersRawValue)
    }
    
    var isValid: Bool {
        return (bundleIdentifier != nil || appURL != nil) && carbonKeyCode != 0
    }
}

struct WindowInfo: Hashable {
    var appName: String
    var windowTitle: String
    var bundleID: String
    var appURL: URL?
    var uniqueIdentifier: String
}

// MARK: - Manager
class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()
    @Published var shortcuts: [AppShortcut] = []
    private var activeHotKeys: [UUID: HotKey] = [:]
    private let saveKey = "com.syns.navx.shortcuts"
    @Published var mruWindowHistory: [WindowInfo] = []
    
    init() {
        print("init start")
        loadShortcuts()
    }
    
    func addEmptyRow() {
        let newRow = AppShortcut(
            appName: "Select Window/App...",
            bundleIdentifier: nil,
            targetKeyword: nil,
            appURL: nil,
            displayKey: "Record Key",
            carbonKeyCode: 0,
            modifiersRawValue: 0
        )
        shortcuts.append(newRow)
        saveShortcut()
    }
    
    func deleteShortcut(id: UUID) {
        if let index = shortcuts.firstIndex(where: {$0.id == id }) {
            activeHotKeys.removeValue(forKey: id)
            shortcuts.remove(at: index)
            saveShortcut()
        }
    }
    
    // Updated to accept window targeting details
    func updateTarget(for id: UUID, appName: String, bundleID: String?, url: URL?, keyword: String?) {
        guard let index = shortcuts.firstIndex(where: { $0.id == id }) else { return }
        shortcuts[index].appName = keyword != nil ? "\(appName) - \(keyword!)" : appName
        shortcuts[index].bundleIdentifier = bundleID
        shortcuts[index].targetKeyword = keyword
        shortcuts[index].appURL = url
        refreshHotKey(at: index)
    }
    
    func updateKey(for id: UUID, display: String, keyCode: UInt32, modifiers: UInt) {
       guard let index = shortcuts.firstIndex(where: { $0.id == id }) else { return }
        shortcuts[index].displayKey = display
        shortcuts[index].carbonKeyCode = keyCode
        shortcuts[index].modifiersRawValue = modifiers
        refreshHotKey(at: index)
    }
    
    private func refreshHotKey(at index: Int) {
        let shortcut = shortcuts[index]
        activeHotKeys.removeValue(forKey: shortcut.id)
        
        if shortcut.isValid {
            guard let key = Key(carbonKeyCode: shortcut.carbonKeyCode) else { return }
            let newHotKey = HotKey(key: key, modifiers: shortcut.modifiers)
            
            newHotKey.keyDownHandler = { [weak self] in
                self?.focusWindowWithPartialMatch(shortcut: shortcut)
            }
            activeHotKeys[shortcut.id] = newHotKey
        }
        saveShortcut()
    }
    
    // MARK: - Execution Logic
    func focusWindowWithPartialMatch(shortcut: AppShortcut) {
        // Fallback to basic open if no bundleID is set
        guard let bundleID = shortcut.bundleIdentifier else {
            if let url = shortcut.appURL {
                NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
            }
            return
        }
        
        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: { $0.bundleIdentifier == bundleID }) else {
            // App isn't running, launch it
            if let url = shortcut.appURL {
                NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
            }
            return
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowList: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowList)

        if result == .success, let windows = windowList as? [AXUIElement] {
            let keyword = shortcut.targetKeyword ?? ""
            
            for window in windows {
                var titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
                let currentTitle = titleRef as? String ?? ""

                // Match logic
                if keyword.isEmpty || currentTitle.localizedCaseInsensitiveContains(keyword) {
                    app.activate(options: [.activateIgnoringOtherApps])
                    AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                    self.centerMouseCursor(on: window)
                    return
                }
            }
        }
        
        // Fallback: If no specific window matches, just bring the app to front
        app.activate(options: [.activateIgnoringOtherApps])
        var focusedWindow: CFTypeRef?
                if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success {
                    let window = focusedWindow as! AXUIElement
                    self.centerMouseCursor(on: window)
                }
    }
    
    // MARK: - Helpers & Persistence
    
    func getOpenWindows() -> [WindowInfo] {
            let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements)
            let windowListInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as! [[String: Any]]
            
            // 1. DYNAMIC PERMISSION CHECK
            // Scan to see if macOS is currently blocking our ability to read titles.
            // If at least one regular app has a title, we know we have permission.
            let hasScreenRecordingPermission = windowListInfo.contains { entry in
                let title = entry[kCGWindowName as String] as? String ?? ""
                let pid = entry[kCGWindowOwnerPID as String] as? Int32 ?? 0
                if let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular {
                    return !title.isEmpty
                }
                return false
            }
            
            var results: [WindowInfo] = []
            var seen = Set<String>()
            
            for entry in windowListInfo {
                let layer = entry[kCGWindowLayer as String] as? Int ?? 0
                guard layer == 0 else { continue }
                
                let alpha = (entry[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1.0
                guard alpha > 0.0 else { continue }
                
                if let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                   let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
                    guard bounds.width > 50 && bounds.height > 50 else { continue }
                }
                
                let ownerName = entry[kCGWindowOwnerName as String] as? String ?? "Unknown App"
                let windowTitle = entry[kCGWindowName as String] as? String ?? ""
                let pid = entry[kCGWindowOwnerPID as String] as? Int32 ?? 0
                let windowID = entry[kCGWindowNumber as String] as? Int ?? 0
                
                guard let app = NSRunningApplication(processIdentifier: pid),
                      app.activationPolicy == .regular,
                      app.bundleIdentifier != Bundle.main.bundleIdentifier else { continue }
                
                // 2. THE ADAPTIVE FILTER
                let uniqueIdentifier: String
                let displayTitle: String
                
                if hasScreenRecordingPermission {
                    // We have permissions!
                    // Any empty title here is 100% an invisible ghost window. Kill it.
                    guard !windowTitle.isEmpty else { continue }
                    
                    uniqueIdentifier = "\(ownerName)-\(windowTitle)"
                    displayTitle = windowTitle
                } else {
                    // We DO NOT have permissions (or Xcode revoked them).
                    // We must let empty titles through and use Window ID so the list isn't blank.
                    uniqueIdentifier = "\(ownerName)-\(windowID)"
                    displayTitle = ownerName
                }
                
                if !seen.contains(uniqueIdentifier) {
                    seen.insert(uniqueIdentifier)
                    
                    results.append(WindowInfo(
                        appName: ownerName,
                        windowTitle: displayTitle,
                        bundleID: app.bundleIdentifier ?? "",
                        appURL: app.bundleURL,
                        uniqueIdentifier: uniqueIdentifier
                    ))
                }
            }
            
            // 3. GROUP BY APP BUT PRESERVE Z-ORDER (MRU)
            // This satisfies the "show all windows" logic without relying on static alphabetical sorting,
            // so the app you just switched to (and all its windows) jumps to the absolute top row in real-time!
//            var groupedResults: [WindowInfo] = []
//            var seenApps = [String]()
//            
//            // Find the true Z-order of applications
//            for window in results {
//                if !seenApps.contains(window.appName) {
//                    seenApps.append(window.appName)
//                }
//            }
//            
//            // Reconstruct the list grouped by App, following MRU order
//            for appName in seenApps {
//                groupedResults.append(contentsOf: results.filter { $0.appName == appName })
//            }
        
        
            results.sort { winA, winB in
                // Find the index of the window in your history.
                // If it's a brand new window not in history yet, assign it Int.max so it drops to the bottom.
                let indexA = mruWindowHistory.firstIndex(where: { $0.uniqueIdentifier == winA.uniqueIdentifier }) ?? Int.max
                let indexB = mruWindowHistory.firstIndex(where: { $0.uniqueIdentifier == winB.uniqueIdentifier }) ?? Int.max
                
                return indexA < indexB
            }
        
            return results
        }
    
    private func saveShortcut() {
        if let encodedData = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(encodedData, forKey: saveKey)
            print("Saved \(shortcuts.count) shortcuts to disk.")
        }
    }
    
    private func loadShortcuts() {
        if let savedData = UserDefaults.standard.data(forKey: saveKey),
           let decodedShortcuts = try? JSONDecoder().decode([AppShortcut].self, from: savedData) {
            self.shortcuts = decodedShortcuts
            for i in 0..<shortcuts.count { refreshHotKey(at: i) }
            print("Loaded \(shortcuts.count) shortcuts from disk.")
        } else {
            print("No saved shortcuts found. Starting fresh.")
        }
    }
    
    func insertCompleteShortcut(_ shortcut: AppShortcut) {
            shortcuts.append(shortcut)
            saveShortcut() // Make sure saveShortcut() is not strictly `private` anymore, or just rely on this method
            refreshHotKey(at: shortcuts.count - 1)
    }
    
    private func centerMouseCursor(on window: AXUIElement) {
            // 1. Add a slight delay. This gives macOS time to slide to a new Space
            // or bring a minimized Xcode/Safari window out of the dock before we calculate coordinates.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                var positionRef: CFTypeRef?
                var sizeRef: CFTypeRef?
                
                // 2. Ask macOS for the window's top-left coordinates and overall size
                guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success,
                      AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success else {
                    return
                }
                
                // Safely ensure we got the right types back (prevents crashes on hidden Safari tabs)
                if CFGetTypeID(positionRef) != AXValueGetTypeID() || CFGetTypeID(sizeRef) != AXValueGetTypeID() {
                    return
                }
                
                let posValue = positionRef as! AXValue
                let sizeValue = sizeRef as! AXValue
                
                var position = CGPoint.zero
                var size = CGSize.zero
                
                // 3. Extract the underlying CGPoint and CGSize
                guard AXValueGetValue(posValue, .cgPoint, &position),
                      AXValueGetValue(sizeValue, .cgSize, &size) else { return }
                
                // Filter out invalid phantom windows (Safari sometimes reports 0x0 size)
                guard size.width > 0 && size.height > 0 else { return }
                
                // 4. Calculate the absolute center of the window
                let centerPoint = CGPoint(
                    x: position.x + (size.width / 2),
                    y: position.y + (size.height / 2)
                )
                
                // 5. The Sledgehammer: Post a system-wide mouse movement event.
                // This is much more reliable across multiple monitors than CGWarpMouseCursorPosition.
                if let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: centerPoint, mouseButton: .left) {
                    moveEvent.post(tap: .cghidEventTap)
                } else {
                    // Fallback just in case
                    CGWarpMouseCursorPosition(centerPoint)
                }
            }
        }
        
        // 2. Update this whenever you switch windows
        func recordWindowSwitch(to window: WindowInfo) {
            // Remove it if it already exists in the history
            mruWindowHistory.removeAll { $0.uniqueIdentifier == window.uniqueIdentifier }
            
            // Unshift it to the very front (index 0)
            mruWindowHistory.insert(window, at: 0)
        }
}
