//
//  GeneralSettingsView.swift
//  Translayr
//

import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(AppSettings.Keys.enabled) private var isEnabled = true
    @State private var hasPermission = AccessibilityPermission.isGranted
    @State private var permissionTimer: Timer?

    var body: some View {
        Form {
            Section("Status") {
                Toggle("Enable Translayr", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, _ in
                        TriggerController.shared.applyEnabledState()
                    }

                HStack {
                    Label("Accessibility Permission",
                          systemImage: hasPermission ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .foregroundColor(hasPermission ? .blue : .orange)
                    Spacer()
                    if hasPermission {
                        Text("Granted").foregroundColor(.blue).fontWeight(.medium)
                    } else {
                        Button("Grant Permission") { AccessibilityPermission.request() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }

                if !hasPermission {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Translayr needs Accessibility permission to read selected text and replace text in other apps.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Open System Settings") { AccessibilityPermission.openSystemSettings() }
                            .controlSize(.small)
                    }
                }
            }

            Section("How to use") {
                Label("Select text, then press \(AppSettings.readShortcut.displayString) to see the translation.",
                      systemImage: "text.magnifyingglass")
                Label("Type in your language, then press \(AppSettings.rewriteShortcut.displayString) to replace it with the translation.",
                      systemImage: "arrow.left.arrow.right")
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("General")
        .onAppear {
            hasPermission = AccessibilityPermission.isGranted
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                Task { @MainActor in hasPermission = AccessibilityPermission.isGranted }
            }
        }
        .onDisappear {
            permissionTimer?.invalidate()
            permissionTimer = nil
        }
    }
}
