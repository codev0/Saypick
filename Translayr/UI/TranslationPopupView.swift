//
//  TranslationPopupView.swift
//  Translayr
//
//  划词翻译弹窗内容（流式展示）。
//

import SwiftUI
import AppKit
import Combine

@MainActor
final class TranslationPopupModel: ObservableObject {
    @Published var original: String
    @Published var translation: String = ""
    @Published var isLoading: Bool = true
    @Published var errorText: String?

    /// 复制译文
    var onCopy: (() -> Void)?
    /// 替换原文（读模式可选；为 nil 时不显示）
    var onReplace: (() -> Void)?

    init(original: String) {
        self.original = original
    }
}

struct TranslationPopupView: View {
    @ObservedObject var model: TranslationPopupModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 380)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 6)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "character.textbox.badge.sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.blue.opacity(0.85))
            Text("Translayr")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
            Button {
                PopupController.shared.close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let err = model.errorText {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if model.translation.isEmpty && model.isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Translating…")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            } else {
                Text(model.translation)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !model.translation.isEmpty && model.errorText == nil {
                HStack(spacing: 10) {
                    Spacer()
                    Button {
                        model.onCopy?()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if model.onReplace != nil {
                        Button {
                            model.onReplace?()
                        } label: {
                            Label("Replace", systemImage: "arrow.left.arrow.right")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
