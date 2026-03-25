//
//  WindowSwitcherPanel.swift
//  navx
//
//  Created by Syns G on 24/02/26.
//

import SwiftUI
import AppKit
import HotKey


// 1. The Custom Panel Class
class SpotlightPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
    
    // Allows us to close it with the Escape key automatically
    override func cancelOperation(_ sender: Any?) {
        self.orderOut(nil)
    }
    
    override func resignKey() {
            super.resignKey()
            self.orderOut(nil)
        }
}

// 2. The Panel Manager
class WindowSwitcherPanelManager {
    static let shared = WindowSwitcherPanelManager()
    private(set) var panel: SpotlightPanel?
    
    private var switcherHotKey: HotKey?
        
    private init() {
        setupGlobalHotkey()
    }

    private func setupGlobalHotkey() {
            // 2. Define Option (⌥) + Slash (/)
            switcherHotKey = HotKey(key: .slash, modifiers: [.option])
            
            // 3. Define the action
            switcherHotKey?.keyDownHandler = { [weak self] in
                DispatchQueue.main.async {
                    // Toggle logic: hide if visible, show if hidden
                    print("Window Shortcut fired")
                    if self?.panel?.isVisible == true {
                        self?.hideSwitcher()
                    } else {
                        self?.showSwitcher()
                    }
                }
            }
        }
    
    func showSwitcher() {
            if panel == nil {
                panel = SpotlightPanel(
                    contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                    styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
                    backing: .buffered,
                    defer: false
                )
                
                // 🔥 THE FIX FOR WORKSPACES:
                panel?.level = .popUpMenu
                // .moveToActiveSpace forces the panel to teleport to your current workspace
                // .fullScreenAuxiliary allows it to show over full-screen apps like Xcode or Safari
                panel?.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
                
                // Visual properties
                panel?.titleVisibility = .hidden
                panel?.titlebarAppearsTransparent = true
                panel?.isMovableByWindowBackground = true
                panel?.backgroundColor = .clear
                panel?.isOpaque = false
                panel?.hasShadow = true
                
                let hostingView = NSHostingView(rootView: WindowSwitcherView())
                hostingView.frame = NSRect(x: 0, y: 0, width: 600, height: 400) // Prevents 0x0 rendering bugs
                panel?.contentView = hostingView
            }
            
            // 1. MULTI-MONITOR FIX: Use NSPointInRect
            let mouseLoc = NSEvent.mouseLocation
            let targetScreen = NSScreen.screens.first { NSPointInRect(mouseLoc, $0.frame) } ?? NSScreen.main
            
            if let screen = targetScreen {
                // 2. Calculate the exact center of the targeted screen
                let newFrame = NSRect(
                    x: screen.visibleFrame.midX - 300,
                    y: screen.visibleFrame.midY - 200,
                    width: 600,
                    height: 400
                )
                
                // 3. Sledgehammer: Force the Window Server to redraw the bounds
                panel?.setFrame(newFrame, display: true)
            }
            
            NotificationCenter.default.post(name: .windowSwithcerOpened, object: nil)
            
            NSApp.activate(ignoringOtherApps: true)
            panel?.makeKeyAndOrderFront(nil)
            panel?.orderFrontRegardless()
        }
    
    func hideSwitcher() {
        panel?.orderOut(nil)
    }
}
