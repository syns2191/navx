//
//  ShortcutRowView.swift
//  navx
//
//  Created by Syns G on 23/02/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ShortcutRowView: View {
    var shortcut: AppShortcut
    @ObservedObject var manager: ShortcutManager
    
    @State private var isRecording = false
    @State private var localEventMonitor: Any?
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 16) {
            
            // 1. Dropdown Menu for Window/App Selection
            Menu {
                Text("Active Windows")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(manager.getOpenWindows(), id: \.self) { window in
                    Button {
                        manager.updateTarget(
                            for: shortcut.id,
                            appName: window.appName,
                            bundleID: window.bundleID,
                            url: window.appURL,
                            keyword: window.windowTitle
                        )
                    } label: {
                        Text("\(window.appName): \(window.windowTitle)")
                    }
                }
                
                Divider()
                
                Button("Browse for App (No Specific Window)...") {
                    selectAppFromDisk()
                }
            } label: {
                HStack(spacing: 12) {
                    if let url = shortcut.appURL {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                            .frame(width: 28, height: 28)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.unemphasizedSelectedContentBackgroundColor))
                            .frame(width: 28, height: 28)
                            .overlay(Image(systemName: "app.dashed").foregroundColor(.secondary))
                    }
                    
                    Text(shortcut.appName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(shortcut.appURL == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .menuStyle(.borderlessButton)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 2. Record Key Button
            Button(action: recordKey) {
                Text(isRecording ? "Listening..." : shortcut.displayKey)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(isRecording ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isRecording ? Color.accentColor : Color(NSColor.unemphasizedSelectedContentBackgroundColor))
                    )
            }
            .buttonStyle(.plain)
            
            // 3. Delete Button
            Button(action: {
                withAnimation { manager.deleteShortcut(id: shortcut.id) }
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
                    .opacity(isHovering ? 1.0 : 0.4)
            }
            .buttonStyle(.plain)
            .frame(width: 20)
        }
        .padding(12)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private func selectAppFromDisk() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            let appName = url.deletingPathExtension().lastPathComponent
            let bundleID = Bundle(url: url)?.bundleIdentifier
            // Pass nil for keyword to target the whole app, not a window
            manager.updateTarget(for: shortcut.id, appName: appName, bundleID: bundleID, url: url, keyword: nil)
        }
    }
    
    private func recordKey() {
        isRecording = true
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let carbonKeyCode = UInt32(event.keyCode)
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            
            var display = ""
            if modifiers.contains(.control) { display += "⌃" }
            if modifiers.contains(.option) { display += "⌥" }
            if modifiers.contains(.shift) { display += "⇧" }
            if modifiers.contains(.command) { display += "⌘" }
            if let char = event.charactersIgnoringModifiers?.uppercased() { display += char }
            
            manager.updateKey(for: shortcut.id, display: display, keyCode: carbonKeyCode, modifiers: modifiers.rawValue)
            
            isRecording = false
            if let monitor = localEventMonitor { NSEvent.removeMonitor(monitor) }
            return nil
        }
    }
}
