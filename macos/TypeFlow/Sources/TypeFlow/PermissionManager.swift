// PermissionManager.swift
// TypeFlow — Accessibility permission state management
//
// Wraps AXIsProcessTrusted() and provides observable state for the UI.
// Also handles opening System Settings to the correct privacy pane.

import Foundation
import AppKit
import ApplicationServices

/// Tracks and manages macOS Accessibility permission for TypeFlow.
///
/// The app uses CGEvent to inject keystrokes into other applications,
/// which requires the user to explicitly grant Accessibility access via
/// System Settings → Privacy & Security → Accessibility.
final class PermissionManager: ObservableObject {
    
    // MARK: - Published State
    
    /// Whether Accessibility permission is currently granted.
    @Published var isGranted: Bool = false
    
    /// Whether permission check is in progress (for "Check Again" spinner).
    @Published var isChecking: Bool = false
    
    // MARK: - Timer
    
    /// Background timer that re-checks permission every 2 seconds
    /// while the permission sheet is visible, so we auto-dismiss
    /// once the user grants access.
    private var pollTimer: Timer?
    
    // MARK: - Public API
    
    /// Check current permission status. Updates `isGranted`.
    func checkPermission() {
        isChecking = true
        
        // AXIsProcessTrusted() is the canonical way to check Accessibility.
        // Passing options: nil means "don't prompt" — we show our own UI.
        let trusted = AXIsProcessTrusted()
        
        DispatchQueue.main.async { [weak self] in
            self?.isGranted = trusted
            self?.isChecking = false
            
            if trusted {
                self?.stopPolling()
            }
        }
    }
    
    /// Prompt: open System Settings to the Accessibility privacy pane
    /// and start polling so we detect when permission is granted.
    func requestPermission() {
        openAccessibilitySettings()
        startPolling()
    }
    
    /// Open System Settings at the Accessibility pane.
    func openAccessibilitySettings() {
        // macOS 13+ URL for System Settings Accessibility pane
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Polling
    
    /// Poll every 2 seconds to detect when the user grants permission.
    func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkPermission()
        }
    }
    
    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    deinit {
        stopPolling()
    }
}
