//
//  AppShortcutsView.swift
//  navx
//
//  Created by Syns G on 23/02/26.
//

import SwiftUI

struct AppShortcutsView: View {
    @ObservedObject var shortcutManager: ShortcutManager
    @StateObject private var listnener = WindowCreationListener.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Pro Header
            VStack(alignment: .leading, spacing: 4) {
                Text("App Shortcuts")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Set global hotkeys to launch your favorite apps instantly.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
            
            // The Polished List
            ScrollView {
                VStack(spacing: 12) {
                    if shortcutManager.shortcuts.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "keyboard.macwindow")
                                .font(.system(size: 40))
                                .foregroundStyle(.quaternary)
                            Text("No shortcuts yet")
                                .font(.headline)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.top, 60)
                    } else {
                        ForEach(shortcutManager.shortcuts) { shortcut in
                            // Calling our newly separated component!
                            ShortcutRowView(shortcut: shortcut, manager: shortcutManager)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Pro Footer
            HStack {
                Toggle("Prompt to add shortcuts for new windows", isOn: $listnener.isListeningForNewWindows)
                Spacer()
                Button(action: {
                    withAnimation(.spring()) { shortcutManager.addEmptyRow() }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Add Shortcut")
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}
