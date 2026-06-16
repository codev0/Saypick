//
//  ShortcutsSettingsView.swift
//  Saypick
//
//  快捷键设置：读·划词翻译 / 写·输入改写。
//

import SwiftUI
import AppKit

struct ShortcutsSettingsView: View {
    @State private var readShortcut = AppSettings.readShortcut
    @State private var rewriteShortcut = AppSettings.rewriteShortcut

    var body: some View {
        Form {
            Section {
                Text("Set global shortcuts. They work in any app.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Section("Shortcuts") {
                ShortcutRecorderRow(title: "Translate selection", shortcut: $readShortcut) { new in
                    AppSettings.readShortcut = new
                    TriggerController.shared.applyEnabledState()
                }
                ShortcutRecorderRow(title: "Rewrite & replace", shortcut: $rewriteShortcut) { new in
                    AppSettings.rewriteShortcut = new
                    TriggerController.shared.applyEnabledState()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Shortcuts")
    }
}

private struct ShortcutRecorderRow: View {
    let title: String
    @Binding var shortcut: KeyboardShortcutPreference
    let onChange: (KeyboardShortcutPreference) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button {
                isRecording ? stop() : start()
            } label: {
                Group {
                    if isRecording {
                        Text("Press keys…").foregroundColor(.secondary)
                    } else {
                        Text(shortcut.displayString).font(.system(.body, design: .monospaced))
                    }
                }
                .frame(minWidth: 90)
            }
            .buttonStyle(.bordered)
        }
        .onDisappear { stop() }
    }

    private func start() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let mods = event.modifierFlags.toShortcutModifiers()
            if !mods.isEmpty {
                let s = KeyboardShortcutPreference(keyCode: Int(event.keyCode), modifiers: mods)
                shortcut = s
                onChange(s)
                stop()
                return nil
            }
            return event
        }
    }

    private func stop() {
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

private extension NSEvent.ModifierFlags {
    func toShortcutModifiers() -> KeyboardShortcutPreference.ModifierFlags {
        var flags = KeyboardShortcutPreference.ModifierFlags()
        if contains(.command) { flags.insert(.command) }
        if contains(.option) { flags.insert(.option) }
        if contains(.control) { flags.insert(.control) }
        if contains(.shift) { flags.insert(.shift) }
        return flags
    }
}
