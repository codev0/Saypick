//
//  TranslayrApp.swift
//  Translayr
//
//  纯菜单栏 App：MenuBarExtra + Settings 场景。
//

import SwiftUI
import TelemetryDeck
import Sentry

@main
struct TranslayrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Translayr", systemImage: "character.textbox.badge.sparkles") {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 纯菜单栏：不在 Dock 显示
        NSApp.setActivationPolicy(.accessory)

        // 监控/分析
        TelemetryDeck.initialize(config: .init(appID: "675A16AE-4E72-4AF8-A128-E1E416B5C3A0"))
        SentrySDK.start { options in
            options.dsn = "https://b872f0c33b8952a7f496ccea32dc623d@o4510180697636864.ingest.us.sentry.io/4510180700258304"
            options.debug = false
            options.sendDefaultPii = true
        }

        // 系统服务
        _ = SystemServiceProvider.shared

        // 注册全局快捷键 + 划词触发
        TriggerController.shared.start()

        // 若配置的 Ollama 模型未安装，自动挑一个已装模型（避免开箱即败）
        Task { @MainActor in
            await OllamaModelResolver.ensureValidDefault()
        }

        // 首次请求辅助功能权限
        if !AccessibilityPermission.isGranted {
            AccessibilityPermission.request()
        }

        // 自动检查更新
        Task { @MainActor in
            if UpdateChecker.shared.shouldAutoCheck() {
                UpdateChecker.shared.checkForUpdates(silent: true)
            }
        }
    }
}
