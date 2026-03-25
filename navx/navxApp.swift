//
//  navxApp.swift
//  navx
//
//  Created by Syns G on 23/02/26.
//

import SwiftUI
import AppKit

@main
struct navxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
