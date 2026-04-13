// PermissionView.swift
// TypeFlow — Full-screen accessibility permission onboarding
//
// Shown as a sheet or dedicated window when the app first launches
// without Accessibility access. Explains why access is needed and
// provides step-by-step instructions with a direct link to System Settings.

import SwiftUI

// MARK: - PermissionView

struct PermissionView: View {
    
    @EnvironmentObject var permissionManager: PermissionManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            
            // ── Header ──────────────────────────────────────────────────
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.blue)
                }
                .padding(.top, 32)
                
                VStack(spacing: 6) {
                    Text("TypeFlow Needs Accessibility Access")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("To simulate keystrokes in other apps, TypeFlow requires Accessibility permission. This is a standard macOS privacy control — TypeFlow only uses this to type text you provide.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }
            }
            .padding(.horizontal, 32)
            
            Divider()
                .padding(.vertical, 24)
            
            // ── Steps ────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 16) {
                Text("How to grant access:")
                    .font(.headline)
                    .padding(.horizontal, 32)
                
                VStack(alignment: .leading, spacing: 12) {
                    StepRow(number: 1,
                            icon: "gear",
                            title: "Open System Settings",
                            description: "Click the button below to open System Settings directly at the Accessibility pane.")
                    
                    StepRow(number: 2,
                            icon: "lock.open.fill",
                            title: "Unlock the settings",
                            description: "Click the lock icon at the bottom left of the Accessibility list, then enter your password.")
                    
                    StepRow(number: 3,
                            icon: "checkmark.square.fill",
                            title: "Enable TypeFlow",
                            description: "Find TypeFlow in the list and toggle it on. If it isn't listed, click + and navigate to the TypeFlow app.")
                    
                    StepRow(number: 4,
                            icon: "arrow.counterclockwise",
                            title: "Return here and click \"Check Again\"",
                            description: "TypeFlow will verify the permission automatically once granted.")
                }
                .padding(.horizontal, 32)
            }
            
            Spacer(minLength: 24)
            
            // ── Actions ──────────────────────────────────────────────────
            VStack(spacing: 10) {
                Button {
                    permissionManager.requestPermission()
                } label: {
                    Label("Open System Settings", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                HStack(spacing: 12) {
                    Button {
                        permissionManager.checkPermission()
                    } label: {
                        if permissionManager.isChecking {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Checking…")
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Label("Check Again", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button("Not Now") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 28)
        }
        .frame(width: 500)
        .onChange(of: permissionManager.isGranted) { granted in
            if granted { dismiss() }
        }
    }
}

// MARK: - StepRow

private struct StepRow: View {
    let number: Int
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Step number badge
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 30, height: 30)
                Text("\(number)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .foregroundColor(.accentColor)
                        .font(.caption)
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PermissionView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionView()
            .environmentObject(PermissionManager())
    }
}
#endif
