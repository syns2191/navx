//
//  WindowCreatedNotification.swift
//  navx
//
//  Created by Syns G on 24/02/26.
//

import SwiftUI
import Combine
import AppKit
import ApplicationServices
import SwiftUI

class WindowCreationListener: ObservableObject {
    static let shared = WindowCreationListener()
    
    @Published var isListeningForNewWindows: Bool = false {
        didSet {
            if isListeningForNewWindows {
                startListening()
            } else {
                stopListening()
            }
        }
    }
    
    private var observers: [pid_t: AXObserver] = [:]
    private var workspaceObserver: Any?
    
    private init() {}
    
    func startListening() {
        // 1. Observe currently running apps
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            addObserver(for: app)
        }
        
        // 2. Listen for newly launched apps to observe them too
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app.activationPolicy == .regular {
                self?.addObserver(for: app)
            }
        }
    }
    
    func stopListening() {
        for (pid, observer) in observers {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observers.removeAll()
        if let workspaceObserver = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
    }
    
    private func addObserver(for app: NSRunningApplication) {
            let pid = app.processIdentifier
            var observer: AXObserver?
            
            // 1. Log the callback firing
            let callback: AXObserverCallback = { (observer, element, notification, refcon) in
                print("🔔 AXObserver triggered: \(notification)") // Is it firing at all?
                guard let refcon = refcon else { return }
                let listener = Unmanaged<WindowCreationListener>.fromOpaque(refcon).takeUnretainedValue()
                listener.handleNewWindow(element: element)
            }
            
            let context = Unmanaged.passUnretained(self).toOpaque()
            let createResult = AXObserverCreate(pid, callback, &observer)
            
            guard createResult == .success, let axObserver = observer else {
                print("❌ Failed to create observer for \(app.localizedName ?? "Unknown"). Error code: \(createResult.rawValue)")
                return
            }
            
            let axApp = AXUIElementCreateApplication(pid)
            let addResult = AXObserverAddNotification(axObserver, axApp, kAXWindowCreatedNotification as CFString, context)
            
            if addResult != .success {
                print("❌ Failed to add notification for \(app.localizedName ?? "Unknown"). Error code: \(addResult.rawValue)")
                return
            }
            
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(axObserver), .defaultMode)
            observers[pid] = axObserver
            print("✅ Successfully attached listener to \(app.localizedName ?? "Unknown")")
        }
    
    func handleNewWindow(element: AXUIElement) {
            print("--- Handle New Window Triggered ---")
            
            // 1. Check the Role
            var roleRef: CFTypeRef?
            let roleResult = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
            let role = roleRef as? String ?? "No Role"
            print("1. Role check: \(role) (API Result: \(roleResult.rawValue))")
            
            // TEMPORARILY DISABLED: Let's see if macOS is reporting something other than "AXWindow"
            guard role == kAXWindowRole else { return }
            
            // 2. Check the PID
            var pid: pid_t = 0
            let pidResult = AXUIElementGetPid(element, &pid)
            print("2. PID check: \(pid) (API Result: \(pidResult.rawValue))")
            
            guard let app = NSRunningApplication(processIdentifier: pid) else {
                print("🛑 BLOCKED: Could not find running app for PID \(pid)")
                return
            }
            
            let bundleID = app.bundleIdentifier ?? "Unknown Bundle"
            print("3. App found: \(app.localizedName ?? "Unknown") (\(bundleID))")
            
            // 3. Check if it's our own app
            if bundleID == Bundle.main.bundleIdentifier {
                print("🛑 BLOCKED: Ignored our own app (navx)")
                return
            }
            
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
            let title = titleRef as? String ?? "No Title Yet"
            print("4. Initial Window Title: \(title)")
            
            print("✅ REACHED UI TRIGGER! Attempting to show panel...")
            
            let appName = app.localizedName ?? "Unknown App"
            
            DispatchQueue.main.async {
                QuickAddPanelManager.shared.showPanel(
                    appName: appName,
                    windowElement: element,
                    bundleID: app.bundleIdentifier,
                    appURL: app.bundleURL
                )
            }
        }
}
