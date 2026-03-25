//
//  PermissionManager.swift
//  navx
//
//  Created by Syns G on 27/02/26.
//


import AppKit
import CoreGraphics

class PermissionsManager {
    static let shared = PermissionsManager()
    
    private init() {}
    
    func checkAndRequestPermissions() {
        checkAccessibility()
        checkScreenRecording()
    }
    
    // MARK: - Accessibility Permission
    private func checkAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        
        if isTrusted {
            print("✅ Accessibility Permission: Granted")
        } else {
            print("❌ Accessibility Permission: Missing (Prompted User)")
        }
    }
    
    // MARK: - Screen Recording Permission
    private func checkScreenRecording() {
        // CGPreflightScreenCaptureAccess() checks if we have permission WITHOUT showing a prompt
        if CGPreflightScreenCaptureAccess() {
            print("✅ Screen Recording Permission: Granted")
        } else {
            print("❌ Screen Recording Permission: Missing. Requesting now...")
            
            // CGRequestScreenCaptureAccess() forces macOS to show the permission popup
            let didGrant = CGRequestScreenCaptureAccess()
            
            if !didGrant {
                // If they already denied it in the past, macOS won't show the popup.
                // We have to open System Settings for them manually.
                print("User previously denied Screen Recording. Opening System Settings...")
                openScreenRecordingSettings()
            }
        }
    }
    
    private func openScreenRecordingSettings() {
        // This specific URL deep-links directly to the Screen Recording privacy tab in macOS Settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
