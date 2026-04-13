// TypeFlowApp.swift
// TypeFlow — Natural human typing simulator for macOS
//
// App entry point. Sets up the main window, scene configuration,
// and performs the initial accessibility permission check on launch.

import SwiftUI
import AppKit

@main
struct TypeFlowApp: App {
    
    // State objects that live for the entire app lifetime
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var typingEngine = TypingEngine()
    @StateObject private var hotkeyManager = HotkeyManager()
    
    var body: some Scene {
        // ── Main Window ──────────────────────────────────────────────────
        WindowGroup {
            ContentView()
                .environmentObject(permissionManager)
                .environmentObject(typingEngine)
                .environmentObject(hotkeyManager)
                .onAppear {
                    // Wire up hotkey manager to the typing engine
                    hotkeyManager.typingEngine = typingEngine
                    
                    // Check accessibility permission on every launch.
                    // The result drives the permission banner in ContentView.
                    permissionManager.checkPermission()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            // Replace default "New Window" with nothing — single-window app
            CommandGroup(replacing: .newItem) { }
            
            // TypeFlow menu item between View and Window
            CommandMenu("TypeFlow") {
                Button("Start Typing (Countdown)") {
                    typingEngine.startWithCountdown()
                }
                .disabled(typingEngine.isTyping || typingEngine.text.isEmpty)
                
                Button("Arm Hotkey (⌘⇧T)") {
                    typingEngine.armForHotkey()
                }
                .disabled(typingEngine.isTyping || typingEngine.text.isEmpty)
                
                Button("Stop Typing") {
                    typingEngine.stop()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!typingEngine.isTyping)
                
                Divider()
                
                Button("Check Accessibility Permission") {
                    permissionManager.checkPermission()
                }
            }
        }
        
        // ── Settings Window (Cmd+,) ──────────────────────────────────────
        Settings {
            SettingsView()
                .environmentObject(typingEngine)
        }
    }
}
