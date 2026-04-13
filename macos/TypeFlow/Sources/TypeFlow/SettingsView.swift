// SettingsView.swift
// TypeFlow — Settings / Preferences window
//
// Accessible via Cmd+, (standard macOS convention).
// Contains advanced settings not shown in the main window:
//   • Countdown duration (3s or 5s)
//   • Micro-pause frequency
//   • Punctuation pause multiplier
//   • Typo rate (percentage)
//   • About section

import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    
    @EnvironmentObject var typingEngine: TypingEngine
    
    // Advanced settings stored in AppStorage (persisted to UserDefaults)
    @AppStorage("countdownSeconds") private var countdownSeconds: Int = 5
    @AppStorage("micropauseMin") private var micropauseMin: Double = 15
    @AppStorage("micropauseMax") private var micropauseMax: Double = 30
    @AppStorage("typoRate") private var typoRate: Double = 4.0
    @AppStorage("punctuationMultiplier") private var punctMultiplier: Double = 1.8
    
    var body: some View {
        TabView {
            typingTab
                .tabItem {
                    Label("Typing", systemImage: "keyboard")
                }
            
            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 420, height: 360)
        .padding()
    }
    
    // MARK: - Typing Tab
    
    private var typingTab: some View {
        Form {
            Section("Countdown") {
                Picker("Duration", selection: $countdownSeconds) {
                    Text("3 seconds").tag(3)
                    Text("5 seconds").tag(5)
                    Text("10 seconds").tag(10)
                }
                .pickerStyle(.segmented)
                Text("Time between clicking Start and when typing begins.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Timing Variation") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Micro-Pause Frequency")
                        Spacer()
                        Text("Every \(Int(micropauseMin))–\(Int(micropauseMax)) chars")
                            .foregroundColor(.accentColor)
                            .font(.caption)
                    }
                    HStack {
                        Text("Min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $micropauseMin, in: 5...25, step: 1)
                        Text("Max")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $micropauseMax, in: 20...60, step: 1)
                    }
                    Text("TypeFlow takes a brief 'thinking pause' approximately every N characters.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Punctuation Pause")
                        Spacer()
                        Text("\(punctMultiplier, specifier: "%.1f")× base delay")
                            .foregroundColor(.accentColor)
                            .font(.caption)
                    }
                    Slider(value: $punctMultiplier, in: 1.0...3.0, step: 0.1)
                    Text("Extra pause after periods, commas, and other punctuation.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Typo Simulation") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Typo Rate")
                        Spacer()
                        Text("\(typoRate, specifier: "%.1f")% of keystrokes")
                            .foregroundColor(.accentColor)
                            .font(.caption)
                    }
                    Slider(value: $typoRate, in: 1.0...10.0, step: 0.5)
                    Text("Percentage of keystrokes that trigger a typo-then-correct sequence.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - About Tab
    
    private var aboutTab: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "keyboard.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            VStack(spacing: 4) {
                Text("TypeFlow")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Version 1.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("TypeFlow simulates natural, human-like typing into any application on your Mac. Paste your text, choose a speed, and let TypeFlow do the rest.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            Spacer()
            
            Text("Built with Swift & SwiftUI · macOS 13+")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(TypingEngine())
    }
}
#endif
