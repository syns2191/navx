//
//  WindowSwitcherViewModel.swift
//  navx
//
//  Created by Syns G on 24/02/26.
//

import SwiftUI
import Combine
import Foundation
import AppKit

import Foundation
import AppKit

enum VimMode {
    case normal
    case insert
}

class WindowSwitcherViewModel: ObservableObject {
    @Published var mode: VimMode = .normal
    
    @Published var searchText: String = "" {
        didSet {
            // Check for the classic Vim "jk" escape sequence
            if searchText.hasSuffix("jk") {
                // Async prevents SwiftUI "modifying state during view update" warnings
                DispatchQueue.main.async {
                    self.searchText = String(self.searchText.dropLast(2))
                    self.mode = .normal
                }
            } else {
                filterWindows()
            }
        }
    }
    
    @Published var filteredWindows: [WindowInfo] = []
    @Published var selectedIndex: Int = 0
    private var allWindows: [WindowInfo] = []
    
    func loadWindows() {
        allWindows = ShortcutManager.shared.getOpenWindows()
        filterWindows()
    }
    
    func resetToNormalMode() {
        mode = .normal
        searchText = ""
        loadWindows() // Refresh the list of active windows
    }
    
    private func filterWindows() {
        let previousSelection = filteredWindows.indices.contains(selectedIndex) ? filteredWindows[selectedIndex] : nil
        
        if searchText.isEmpty {
            filteredWindows = allWindows
        } else {
            filteredWindows = allWindows.filter { window in
                window.appName.localizedCaseInsensitiveContains(searchText) ||
                window.windowTitle.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Preserve selection during live updates
        if let prev = previousSelection, let newIndex = filteredWindows.firstIndex(of: prev) {
            selectedIndex = newIndex
        } else {
            selectedIndex = 0
        }
    }
    
    func moveSelectionDown() {
        if selectedIndex < filteredWindows.count - 1 { selectedIndex += 1 }
    }
    
    func moveSelectionUp() {
        if selectedIndex > 0 { selectedIndex -= 1 }
    }
    
    func focusSelectedWindow() {
        guard filteredWindows.indices.contains(selectedIndex) else { return }
        let target = filteredWindows[selectedIndex]
        
        ShortcutManager.shared.recordWindowSwitch(to: target)
        
        let shortcut = AppShortcut(
            appName: target.appName,
            bundleIdentifier: target.bundleID,
            targetKeyword: target.windowTitle,
            appURL: target.appURL,
            displayKey: "", carbonKeyCode: 0, modifiersRawValue: 0
        )
        
        ShortcutManager.shared.focusWindow(shortcut)
        WindowSwitcherPanelManager.shared.hideSwitcher()
    }
}

// Add this quick helper extension to ShortcutManager.swift to expose the focus logic cleanly:
extension ShortcutManager {
    func focusWindow(_ shortcut: AppShortcut) {
        // Just call your existing private focus logic
        self.focusWindowWithPartialMatch(shortcut: shortcut)
    }
}
