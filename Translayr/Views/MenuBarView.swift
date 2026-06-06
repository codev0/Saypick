import SwiftUI
import AppKit

/// 菜单栏视图：开关、快捷键提示、设置入口。
struct MenuBarView: View {
    @StateObject private var updateChecker = UpdateChecker.shared
    @AppStorage(AppSettings.Keys.enabled) private var isEnabled = true

    var body: some View {
        if updateChecker.hasNewVersion {
            Button {
                updateChecker.openReleasesPage()
            } label: {
                Label("New update available", systemImage: "arrow.down.circle.fill")
            }
            Divider()
        }

        Toggle(isOn: $isEnabled) {
            Text(isEnabled ? "Translayr is On" : "Translayr is Off")
        }
        .onChange(of: isEnabled) { _, _ in
            TriggerController.shared.applyEnabledState()
        }

        Divider()

        Text("Translate selection:  \(AppSettings.readShortcut.displayString)")
        Text("Rewrite & replace:    \(AppSettings.rewriteShortcut.displayString)")

        Divider()

        SettingsLink {
            Label("Settings…", systemImage: "gearshape")
        }
        .keyboardShortcut(",", modifiers: .command)

        Button(role: .destructive) {
            NSApp.terminate(nil)
        } label: {
            Label("Quit Translayr", systemImage: "power")
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
