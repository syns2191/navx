//
//  AppDelegate.swift
//  navx
//
//  Created by Syns G on 23/02/26.
//
import SwiftUI
import AppKit

extension Notification.Name {
    static let windowSwithcerOpened = Notification.Name("windowSwitcherOpened")
}


class AppDelegate: NSObject, NSApplicationDelegate {
    var shortcutManager: ShortcutManager?
    
    var statusItem: NSStatusItem?
    
    var preferencesWindow: NSWindow?
    var workspaceManager: WorkspaceManager?
    var windowSwitcherPanelManager: WindowSwitcherPanelManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("AppDelegate: App finished launching")
        PermissionsManager.shared.checkAndRequestPermissions()
        shortcutManager = ShortcutManager.shared
        workspaceManager = WorkspaceManager()
        windowSwitcherPanelManager = WindowSwitcherPanelManager.shared
        
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(named: "TrayIcon")
            button.image?.accessibilityDescription = "navx"
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preference", action: #selector(openPreferences), keyEquivalent: ","))
        statusItem?.menu = menu
        
        
        
    }
    
    @objc func openPreferences() {
        if preferencesWindow == nil {
            guard let manager = shortcutManager else { return }
            guard let wsManager = workspaceManager else { return }
            
            let rootView = PreferenceView(shortcutManager: manager, workspaceManager: wsManager)
            let hostingController = NSHostingController(rootView: rootView)
            preferencesWindow = NSWindow(contentViewController: hostingController)
            preferencesWindow?.title = "Preference"
            preferencesWindow?.styleMask = [.titled, .closable, .miniaturizable]
        }
        
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
