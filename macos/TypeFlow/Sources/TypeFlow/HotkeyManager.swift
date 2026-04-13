// HotkeyManager.swift
// TypeFlow — Global hotkey registration using CGEventTap
//
// Registers two global hotkeys via CGEventTap:
//   • Cmd+Shift+T  →  Start typing (triggers TypingEngine.beginTyping())
//   • Escape        →  Stop typing  (triggers TypingEngine.stop())
//
// CGEventTap requires Accessibility permission (same as keystroke injection).
// The tap is created lazily when typing is started or when the user grants
// Accessibility access.

import Foundation
import AppKit
import CoreGraphics

// MARK: - HotkeyManager

final class HotkeyManager: ObservableObject {
    
    // MARK: - Properties
    
    /// Weak reference to the engine; set by TypeFlowApp on launch.
    weak var typingEngine: TypingEngine?
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // MARK: - Setup
    
    /// Install the global event tap. Must be called after Accessibility is granted.
    func install() {
        guard eventTap == nil else { return } // Already installed
        
        // We only want key-down events
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        
        // The callback needs a C-compatible context pointer
        let context = Unmanaged.passRetained(self)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: context.toOpaque()
        ) else {
            // Tap creation failed — usually means no Accessibility permission
            context.release()
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    
    /// Remove the event tap (e.g., when app quits or permission is revoked).
    func uninstall() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
    }
    
    // MARK: - Event Handling
    
    /// Called for every key-down event. Returns nil to suppress the event,
    /// or the event unchanged to let it pass through.
    private func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        
        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }
        
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        // Cmd+Shift+T (keyCode 17 = 't')
        let isCmdShift = flags.contains(.maskCommand) && flags.contains(.maskShift)
        if isCmdShift && keyCode == 17 {
            DispatchQueue.main.async { [weak self] in
                guard let engine = self?.typingEngine else { return }
                // Only trigger if engine is armed (hotkey mode) and not already typing
                if engine.state == .armed && !engine.text.isEmpty {
                    engine.beginTyping()
                }
            }
            return nil // Suppress the event so it doesn't type "T" in TypeFlow itself
        }
        
        // Escape (keyCode 53) — stop typing
        if keyCode == 53 {
            DispatchQueue.main.async { [weak self] in
                self?.typingEngine?.stop()
            }
            // Don't suppress Escape globally — it has many other uses
        }
        
        // Cmd+Shift+S (keyCode 1 = 's') — alternate stop
        if isCmdShift && keyCode == 1 {
            DispatchQueue.main.async { [weak self] in
                self?.typingEngine?.stop()
            }
            return nil
        }
        
        return Unmanaged.passRetained(event)
    }
    
    deinit {
        uninstall()
    }
}
