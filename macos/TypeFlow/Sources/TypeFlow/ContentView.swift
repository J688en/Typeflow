// ContentView.swift
// TypeFlow — Main application window
//
// Layout:
//   • Permission banner (conditional — shown when Accessibility is not granted)
//   • Text input area with character count
//   • Settings card (WPM slider, typo toggle, start method picker)
//   • Progress section
//   • Control buttons (Start / Stop)

import SwiftUI
import AppKit

// MARK: - ContentView

struct ContentView: View {
    
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var typingEngine: TypingEngine
    @EnvironmentObject var hotkeyManager: HotkeyManager
    
    @State private var showingPermissionSheet = false
    
    // Install hotkeys once permission is granted
    private var hotkeyInstalled = false
    
    var body: some View {
        VStack(spacing: 0) {
            
            // ── Permission Banner ──────────────────────────────────────────
            if !permissionManager.isGranted {
                PermissionBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            ScrollView {
                VStack(spacing: 16) {
                    
                    // ── Text Input ─────────────────────────────────────────
                    TextInputSection()
                    
                    // ── Settings ────────────────────────────────────────────
                    SettingsSection()
                    
                    // ── Progress ────────────────────────────────────────────
                    ProgressSection()
                    
                    // ── Controls ────────────────────────────────────────────
                    ControlSection()
                    
                }
                .padding(16)
            }
        }
        .frame(minWidth: 480, idealWidth: 500, maxWidth: 700,
               minHeight: 560, idealHeight: 620, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: permissionManager.isGranted)
        .onChange(of: permissionManager.isGranted) { granted in
            if granted {
                // Install hotkeys once we have permission
                hotkeyManager.install()
            }
        }
        .onAppear {
            if permissionManager.isGranted {
                hotkeyManager.install()
            }
        }
    }
}

// MARK: - Permission Banner

private struct PermissionBanner: View {
    @EnvironmentObject var permissionManager: PermissionManager
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundColor(.orange)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility Access Required")
                    .font(.headline)
                Text("TypeFlow needs permission to simulate keystrokes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Grant Access") {
                permissionManager.requestPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            
            Button {
                permissionManager.checkPermission()
            } label: {
                if permissionManager.isChecking {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Check Again")
                }
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.12))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.orange.opacity(0.3)),
            alignment: .bottom
        )
    }
}

// MARK: - Text Input Section

private struct TextInputSection: View {
    @EnvironmentObject var typingEngine: TypingEngine
    
    private var charCount: Int { typingEngine.text.count }
    private var wordCount: Int {
        typingEngine.text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Text to Type", systemImage: "text.alignleft")
                        .font(.headline)
                    Spacer()
                    Text("\(wordCount) words · \(charCount) chars")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ZStack(alignment: .topLeading) {
                    // Placeholder
                    if typingEngine.text.isEmpty {
                        Text("Paste or type the text you want TypeFlow to simulate…")
                            .foregroundColor(Color(NSColor.placeholderTextColor))
                            .font(.body)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    
                    TextEditor(text: $typingEngine.text)
                        .font(.body)
                        .frame(minHeight: 160, maxHeight: 260)
                        .disabled(typingEngine.isTyping)
                        .opacity(typingEngine.isTyping ? 0.6 : 1.0)
                }
                
                if typingEngine.isTyping {
                    Label("Editing disabled while typing is active.", systemImage: "lock.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(4)
        }
    }
}

// MARK: - Settings Section

private struct SettingsSection: View {
    @EnvironmentObject var typingEngine: TypingEngine
    
    var body: some View {
        GroupBox {
            VStack(spacing: 12) {
                
                // Title row
                HStack {
                    Label("Settings", systemImage: "slider.horizontal.3")
                        .font(.headline)
                    Spacer()
                }
                
                Divider()
                
                // WPM Slider
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Typing Speed")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(typingEngine.wpm)) WPM")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                            .frame(width: 70, alignment: .trailing)
                    }
                    
                    HStack(spacing: 8) {
                        Text("30")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $typingEngine.wpm, in: 30...120, step: 1)
                            .disabled(typingEngine.isTyping)
                        Text("120")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(wpmDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Typo toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Typo Simulation")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Occasionally mistype a character, pause, then correct it (~4% of keystrokes)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $typingEngine.typoEnabled)
                        .labelsHidden()
                        .disabled(typingEngine.isTyping)
                }
                
                Divider()
                
                // Start method picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start Method")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Start Method", selection: $typingEngine.startMethod) {
                        ForEach(StartMethod.allCases) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .disabled(typingEngine.isTyping)
                    
                    startMethodHint
                }
            }
            .padding(4)
        }
    }
    
    private var wpmDescription: String {
        switch typingEngine.wpm {
        case 30..<50:  return "Slow — very natural, beginner typist"
        case 50..<70:  return "Average — comfortable everyday typing"
        case 70..<90:  return "Fast — proficient typist"
        case 90..<110: return "Very fast — skilled touch typist"
        default:        return "Expert — near professional speed"
        }
    }
    
    @ViewBuilder
    private var startMethodHint: some View {
        switch typingEngine.startMethod {
        case .countdown:
            Label("Click Start — a 5-second countdown begins, then typing starts at the current cursor position.", systemImage: "timer")
                .font(.caption)
                .foregroundColor(.secondary)
        case .hotkey:
            Label("Click Start, switch to your target app, then press ⌘⇧T to begin typing. Press Escape or ⌘⇧S to stop.", systemImage: "keyboard")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Progress Section

private struct ProgressSection: View {
    @EnvironmentObject var typingEngine: TypingEngine
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Progress", systemImage: "chart.bar.fill")
                        .font(.headline)
                    Spacer()
                    statusBadge
                }
                
                ProgressView(value: typingEngine.progress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .animation(.easeInOut(duration: 0.2), value: typingEngine.progress)
                
                HStack {
                    Text("\(typingEngine.typedCharacters) / \(typingEngine.text.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(typingEngine.progress * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(4)
        }
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        switch typingEngine.state {
        case .idle:
            Label("Idle", systemImage: "circle")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())
        
        case .armed:
            Label("Armed — waiting for ⌘⇧T", systemImage: "keyboard.badge.ellipsis")
                .font(.caption)
                .foregroundColor(.purple)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.purple.opacity(0.12))
                .clipShape(Capsule())
            
        case .countdown(let n):
            Label("Starting in \(n)…", systemImage: "timer")
                .font(.caption)
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.12))
                .clipShape(Capsule())
            
        case .typing:
            Label("Typing…", systemImage: "keyboard.fill")
                .font(.caption)
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.12))
                .clipShape(Capsule())
            
        case .paused:
            Label("Paused", systemImage: "pause.fill")
                .font(.caption)
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.12))
                .clipShape(Capsule())
            
        case .finished:
            Label("Done!", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.12))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Control Section

private struct ControlSection: View {
    @EnvironmentObject var typingEngine: TypingEngine
    @EnvironmentObject var permissionManager: PermissionManager
    
    var body: some View {
        HStack(spacing: 12) {
            
            // Clear button
            Button {
                typingEngine.text = ""
                typingEngine.stop()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .disabled(typingEngine.isTyping || typingEngine.text.isEmpty)
            
            Spacer()
            
            // Stop button
            Button {
                typingEngine.stop()
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .keyboardShortcut(.escape, modifiers: [])
            .disabled(!typingEngine.isTyping)
            .tint(.red)
            
            // Start button
            startButton
        }
        .controlSize(.large)
    }
    
    @ViewBuilder
    private var startButton: some View {
        let isCountdown = typingEngine.startMethod == .countdown
        let isEmpty = typingEngine.text.isEmpty
        let noPermission = !permissionManager.isGranted
        
        Group {
            switch typingEngine.state {
            case .countdown(let n):
                // During countdown: show a cancellable countdown button
                Button {
                    typingEngine.stop()
                } label: {
                    Label("Starting in \(n)… (cancel)", systemImage: "timer")
                        .frame(minWidth: 180)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                
            case .typing:
                // While typing: the button shows live status (tap to stop)
                Button {
                    typingEngine.stop()
                } label: {
                    Label("Typing… (stop)", systemImage: "keyboard.fill")
                        .frame(minWidth: 180)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
            case .armed:
                // Armed for hotkey: waiting for Cmd+Shift+T in another app
                Button {
                    typingEngine.stop()
                } label: {
                    Label("Armed — press ⌘⇧T to type (cancel)", systemImage: "keyboard.badge.ellipsis")
                        .frame(minWidth: 180)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                
            default:
                // Idle or finished: show Start button
                Button {
                    if isCountdown {
                        typingEngine.startWithCountdown()
                    } else {
                        // Hotkey mode: arm the engine; user switches to target app and presses ⌘⇧T
                        typingEngine.armForHotkey()
                    }
                } label: {
                    Label(
                        isCountdown ? "Start (5s countdown)" : "Arm Hotkey (⌘⇧T)",
                        systemImage: isCountdown ? "play.fill" : "keyboard"
                    )
                    .frame(minWidth: 180)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isEmpty || noPermission)
                .help(noPermission ? "Grant Accessibility access first" : "")
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(PermissionManager())
            .environmentObject(TypingEngine())
            .environmentObject(HotkeyManager())
    }
}
#endif
