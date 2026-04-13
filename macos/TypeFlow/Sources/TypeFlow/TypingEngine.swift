// TypingEngine.swift
// TypeFlow — Core typing simulation engine
//
// Uses CGEvent to post keyboard events to the system's current focus,
// simulating human-like typing with randomized timing, natural pauses,
// and optional typo simulation.

import Foundation
import AppKit
import CoreGraphics

// MARK: - Typing State

/// The current operational state of the typing engine.
enum TypingState: Equatable {
    case idle
    case armed            // waiting for hotkey press
    case countdown(Int)   // seconds remaining
    case typing
    case paused
    case finished
}

// MARK: - TypingEngine

/// Observable object that drives the typing simulation.
///
/// Scheduling uses a recursive DispatchQueue approach rather than Timer
/// to achieve sub-millisecond precision on keystroke timing. All UI
/// state updates are dispatched back to the main queue.
final class TypingEngine: ObservableObject {
    
    // MARK: - Published State
    
    @Published var text: String = ""
    @Published var state: TypingState = .idle
    @Published var progress: Double = 0.0          // 0.0 – 1.0
    @Published var typedCharacters: Int = 0
    
    /// True while actively typing (armed, countdown, or actual typing).
    var isTyping: Bool {
        switch state {
        case .idle, .finished: return false
        default: return true
        }
    }
    
    // MARK: - Settings (bound from UI)
    
    /// Target words per minute (30–120).
    var wpm: Double = 60
    
    /// Whether to inject occasional realistic typos.
    var typoEnabled: Bool = true
    
    /// Start method: countdown timer or hotkey trigger.
    var startMethod: StartMethod = .countdown
    
    // MARK: - Private State
    
    private let typingQueue = DispatchQueue(label: "com.typeflow.typingQueue", qos: .userInteractive)
    private var isCancelled = false
    private var countdownTimer: Timer?
    
    // MARK: - Timing Calculations
    
    /// Base delay between characters, in seconds.
    /// Formula: 60 / (wpm × 5) = seconds per character
    private var baseCharDelay: Double {
        60.0 / (wpm * 5.0)
    }
    
    /// Randomized delay for a given character.
    /// - Parameters:
    ///   - char: The character about to be typed (affects punctuation pauses).
    ///   - charIndex: Position in the string (drives micro-pause logic).
    private func delay(for char: Character, at charIndex: Int) -> Double {
        let base = baseCharDelay
        
        // ±30% random jitter
        let jitter = base * 0.3 * Double.random(in: -1.0...1.0)
        var delay = base + jitter
        
        // Longer pause after sentence-ending punctuation
        if char == "." || char == "!" || char == "?" {
            delay *= Double.random(in: 1.8...2.5)
        } else if char == "," || char == ";" || char == ":" {
            delay *= Double.random(in: 1.3...1.7)
        }
        
        // Occasional micro-pause every 15–30 characters (simulates "thinking")
        if charIndex > 0 && charIndex % Int.random(in: 15...30) == 0 {
            delay += Double.random(in: 0.15...0.45)
        }
        
        // Clamp to a reasonable range
        return max(0.02, min(delay, 1.5))
    }
    
    // MARK: - Public Control
    
    /// Start with a 5-second countdown, then begin typing.
    func startWithCountdown() {
        guard !text.isEmpty, !isTyping else { return }
        resetProgress()
        isCancelled = false
        
        var remaining = 5
        state = .countdown(remaining)
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            remaining -= 1
            if remaining <= 0 {
                timer.invalidate()
                self.beginTyping()
            } else {
                self.state = .countdown(remaining)
            }
        }
    }
    
    /// Begin typing immediately (used by hotkey trigger and after countdown).
    func beginTyping() {
        guard !text.isEmpty else { return }
        isCancelled = false
        state = .typing
        
        let chars = Array(text)
        scheduleNextCharacter(chars: chars, index: 0)
    }
    
    /// Arm the engine for hotkey-triggered typing.
    /// Sets state to .armed so HotkeyManager knows it can fire.
    func armForHotkey() {
        guard !text.isEmpty else { return }
        resetProgress()
        isCancelled = false
        state = .armed
    }
    
    /// Stop typing at any time.
    func stop() {
        isCancelled = true
        countdownTimer?.invalidate()
        countdownTimer = nil
        
        DispatchQueue.main.async { [weak self] in
            self?.state = .idle
        }
    }
    
    // MARK: - Private Typing Loop
    
    private func scheduleNextCharacter(chars: [Character], index: Int) {
        guard !isCancelled else {
            DispatchQueue.main.async { [weak self] in
                self?.state = .idle
            }
            return
        }
        
        guard index < chars.count else {
            // Finished
            DispatchQueue.main.async { [weak self] in
                self?.state = .finished
                self?.progress = 1.0
            }
            return
        }
        
        let char = chars[index]
        let waitTime = delay(for: char, at: index)
        
        typingQueue.asyncAfter(deadline: .now() + waitTime) { [weak self] in
            guard let self = self, !self.isCancelled else { return }
            
            // Decide whether to inject a typo before this character
            if self.typoEnabled && self.shouldInjectTypo() {
                self.typeWithTypo(correctChar: char) {
                    self.updateProgress(index: index, total: chars.count)
                    self.scheduleNextCharacter(chars: chars, index: index + 1)
                }
            } else {
                self.typeCharacter(char)
                self.updateProgress(index: index, total: chars.count)
                self.scheduleNextCharacter(chars: chars, index: index + 1)
            }
        }
    }
    
    /// ~4% chance of injecting a typo.
    private func shouldInjectTypo() -> Bool {
        return Double.random(in: 0...1) < 0.04
    }
    
    /// Type a wrong character, pause, backspace, pause, type the correct character.
    private func typeWithTypo(correctChar: Character, completion: @escaping () -> Void) {
        let wrongChar = randomNearbyCharacter(for: correctChar)
        
        // Type the wrong character
        typeCharacter(wrongChar)
        
        // Pause 200–400ms as if noticing the mistake
        typingQueue.asyncAfter(deadline: .now() + Double.random(in: 0.2...0.4)) { [weak self] in
            guard let self = self, !self.isCancelled else { return }
            
            // Backspace the typo
            self.typeKeyCode(51) // kVK_Delete = 51
            
            // Brief pause 100–200ms, then type correct character
            self.typingQueue.asyncAfter(deadline: .now() + Double.random(in: 0.1...0.2)) { [weak self] in
                guard let self = self, !self.isCancelled else { return }
                self.typeCharacter(correctChar)
                completion()
            }
        }
    }
    
    /// Pick a character that's plausibly adjacent on a QWERTY keyboard.
    private func randomNearbyCharacter(for char: Character) -> Character {
        let adjacency: [Character: [Character]] = [
            "a": ["s", "q", "z", "w"],
            "b": ["v", "g", "h", "n"],
            "c": ["x", "d", "f", "v"],
            "d": ["s", "e", "f", "r", "c", "x"],
            "e": ["w", "r", "d", "s"],
            "f": ["d", "r", "g", "t", "v", "c"],
            "g": ["f", "t", "h", "y", "b", "v"],
            "h": ["g", "y", "j", "u", "n", "b"],
            "i": ["u", "o", "k", "j"],
            "j": ["h", "u", "k", "i", "n", "m"],
            "k": ["j", "i", "l", "o", "m"],
            "l": ["k", "o", "p", ";"],
            "m": ["n", "j", "k", ","],
            "n": ["b", "h", "j", "m"],
            "o": ["i", "p", "l", "k"],
            "p": ["o", "l", ";", "["],
            "q": ["w", "a"],
            "r": ["e", "t", "f", "d"],
            "s": ["a", "w", "d", "e", "x", "z"],
            "t": ["r", "y", "g", "f"],
            "u": ["y", "i", "h", "j"],
            "v": ["c", "f", "g", "b"],
            "w": ["q", "e", "a", "s"],
            "x": ["z", "s", "d", "c"],
            "y": ["t", "u", "g", "h"],
            "z": ["a", "s", "x"],
        ]
        
        let lower = Character(char.lowercased())
        if let neighbors = adjacency[lower], !neighbors.isEmpty {
            let neighbor = neighbors.randomElement()!
            // Preserve capitalization with 50% probability
            if char.isUppercase && Bool.random() {
                return Character(neighbor.uppercased())
            }
            return neighbor
        }
        
        // Fallback: swap with a random lowercase letter
        let fallbacks: [Character] = ["a","s","d","f","j","k","l"]
        return fallbacks.randomElement() ?? "x"
    }
    
    // MARK: - CGEvent Keystroke Injection
    
    /// Post a Unicode character as a CGEvent keystroke.
    private func typeCharacter(_ char: Character) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        
        let scalars = char.unicodeScalars
        guard let scalar = scalars.first else { return }
        let utf16 = [UniChar(scalar.value & 0xFFFF)]
        
        // For printable characters, use key-down/key-up with the Unicode value
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
            keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            keyDown.post(tap: .cghidEventTap)
        }
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
            keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            keyUp.post(tap: .cghidEventTap)
        }
    }
    
    /// Post a hardware key code (e.g., backspace = 51).
    private func typeKeyCode(_ keyCode: CGKeyCode) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
            keyDown.post(tap: .cghidEventTap)
        }
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
            keyUp.post(tap: .cghidEventTap)
        }
    }
    
    // MARK: - Progress
    
    private func updateProgress(index: Int, total: Int) {
        let p = Double(index + 1) / Double(total)
        DispatchQueue.main.async { [weak self] in
            self?.progress = p
            self?.typedCharacters = index + 1
        }
    }
    
    private func resetProgress() {
        progress = 0.0
        typedCharacters = 0
    }
}

// MARK: - StartMethod

enum StartMethod: String, CaseIterable, Identifiable {
    case countdown = "5-Second Countdown"
    case hotkey    = "Global Hotkey (⌘⇧T)"
    
    var id: String { rawValue }
}
