//
//  TriggerController.swift
//  Translayr
//
//  编排主链路：
//  - 读·划词翻译：快捷键 / 划词图标 / 自动 → 弹窗流式显示译文。
//  - 写·输入改写：快捷键 → 译为目标语言 → 直接替换或先预览。
//

import AppKit
import ApplicationServices

@MainActor
final class TriggerController {
    static let shared = TriggerController()
    private init() {}

    private let readHotkeyID: UInt32 = 1
    private let rewriteHotkeyID: UInt32 = 2

    private var streamTask: Task<Void, Never>?
    private var rewriteTask: Task<Void, Never>?

    /// 母语（读模式的目标 / 写模式的源）
    private var nativeLanguage: Language { LanguageConfig.sourceLanguage }
    /// 外语（写模式的目标）
    private var foreignLanguage: Language { LanguageConfig.targetLanguage }

    // MARK: - 生命周期

    func start() {
        applyEnabledState()
    }

    /// 根据开关 + 快捷键 + 划词设置重新装配触发。
    func applyEnabledState() {
        GlobalShortcutCenter.shared.unregisterAll()
        SelectionMonitor.shared.stop()
        SelectionIconWindow.shared.hide()

        guard AppSettings.isEnabled else { return }

        GlobalShortcutCenter.shared.register(id: readHotkeyID, shortcut: AppSettings.readShortcut) { [weak self] in
            Task { @MainActor in self?.handleRead() }
        }
        GlobalShortcutCenter.shared.register(id: rewriteHotkeyID, shortcut: AppSettings.rewriteShortcut) { [weak self] in
            Task { @MainActor in self?.handleRewrite() }
        }

        setupSelectionTrigger()
    }

    private func setupSelectionTrigger() {
        let mode = AppSettings.selectionTrigger
        guard mode != .none else { return }

        SelectionMonitor.shared.onSelection = { [weak self] text, location, element, range in
            guard let self, AppSettings.isEnabled, AccessibilityPermission.isGranted else { return }
            switch mode {
            case .none:
                break
            case .icon:
                // 图标贴合选区：优先用选区屏幕矩形，拿不到再退回鼠标点
                let anchor = PopupPositioner.anchorRect(element: element, range: range)
                SelectionIconWindow.shared.show(near: anchor, fallback: location) {
                    self.presentRead(text: text, element: element, range: range)
                }
            case .auto:
                self.presentRead(text: text, element: element, range: range)
            }
        }
        SelectionMonitor.shared.start()
    }

    // MARK: - 读·划词翻译

    func handleRead() {
        guard AppSettings.isEnabled, AccessibilityPermission.isGranted else { return }
        Task { @MainActor in
            guard let cap = await SelectionCapture.readSelection() else { return }
            presentRead(text: cap.text, element: cap.element, range: cap.range)
        }
    }

    /// 显示读翻译弹窗并流式填充（供快捷键 / 图标 / 自动模式共用）。
    func presentRead(text: String, element: AXUIElement?, range: CFRange?) {
        streamTask?.cancel()
        let anchor = PopupPositioner.anchorRect(element: element, range: range)
        let model = PopupController.shared.show(original: text, anchor: anchor, onReplace: nil)
        model.onReplace = { [weak model] in
            guard let model, !model.translation.isEmpty else { return }
            Task { @MainActor in
                PopupController.shared.close()
                await TextReplacer.replace(with: model.translation, selectAll: false)
            }
        }
        streamTask = Task { @MainActor in
            do {
                for try await delta in TranslationService.shared.stream(text: text, from: nil, to: nativeLanguage, style: AppSettings.readStyle) {
                    if Task.isCancelled { return }
                    model.translation += delta
                    model.isLoading = false
                }
                model.isLoading = false
                if model.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    model.errorText = "No translation returned"
                }
            } catch {
                model.isLoading = false
                model.errorText = (error as? TranslationError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    // MARK: - 写·输入改写

    func handleRewrite() {
        guard AppSettings.isEnabled, AccessibilityPermission.isGranted else { return }
        rewriteTask?.cancel()
        rewriteTask = Task { @MainActor in
            guard let cap = await SelectionCapture.captureForRewrite() else { return }
            let style = AppSettings.rewriteStyle

            if AppSettings.rewritePreview {
                // 先预览：弹窗显示译文 + Replace 按钮
                let anchor = PopupPositioner.anchorRect(element: cap.element, range: cap.selectedRange)
                let model = PopupController.shared.show(original: cap.text, anchor: anchor, onReplace: nil)
                model.onReplace = { [weak model] in
                    guard let model, !model.translation.isEmpty else { return }
                    Task { @MainActor in
                        PopupController.shared.close()
                        await TextReplacer.replace(with: model.translation, selectAll: cap.isWholeField)
                    }
                }
                do {
                    for try await delta in TranslationService.shared.stream(
                        text: cap.text, from: nativeLanguage, to: foreignLanguage, style: style) {
                        if Task.isCancelled { return }
                        model.translation += delta
                        model.isLoading = false
                    }
                    model.isLoading = false
                } catch {
                    model.isLoading = false
                    model.errorText = (error as? TranslationError)?.errorDescription ?? error.localizedDescription
                }
            } else {
                // 直接替换
                do {
                    let translated = try await TranslationService.shared.translateFully(
                        text: cap.text, from: nativeLanguage, to: foreignLanguage, style: style)
                    await TextReplacer.replace(with: translated, selectAll: cap.isWholeField)
                } catch {
                    let anchor = PopupPositioner.anchorRect(element: cap.element, range: cap.selectedRange)
                    let model = PopupController.shared.show(original: cap.text, anchor: anchor, onReplace: nil)
                    model.isLoading = false
                    model.errorText = (error as? TranslationError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }
}
