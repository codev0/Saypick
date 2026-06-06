//
//  BackendSettingsView.swift
//  Translayr
//
//  翻译后端设置：本地 Ollama / OpenAI 兼容。
//

import SwiftUI

struct BackendSettingsView: View {
    @AppStorage(AppSettings.Keys.backend) private var backendRaw = TranslationBackend.ollama.rawValue
    @AppStorage(AppSettings.Keys.openAIBaseURL) private var openAIBaseURL = "https://api.openai.com/v1"
    @AppStorage(AppSettings.Keys.openAIKey) private var openAIKey = ""
    @AppStorage(AppSettings.Keys.openAIModel) private var openAIModel = "gpt-4o-mini"
    @AppStorage(AppSettings.Keys.ollamaModel) private var ollamaModel = "qwen2.5:3b"

    var body: some View {
        Form {
            Section("Backend") {
                Picker("Translation backend", selection: $backendRaw) {
                    ForEach(TranslationBackend.allCases) { backend in
                        Text(backend.displayName).tag(backend.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            if backendRaw == TranslationBackend.openai.rawValue {
                Section("OpenAI-compatible") {
                    TextField("Base URL", text: $openAIBaseURL)
                        .textFieldStyle(.roundedBorder)
                    SecureField("API Key", text: $openAIKey)
                        .textFieldStyle(.roundedBorder)
                    TextField("Model", text: $openAIModel)
                        .textFieldStyle(.roundedBorder)
                    Text("Works with any OpenAI-compatible /chat/completions endpoint (official API, proxies, local servers).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Section("Ollama") {
                    LabeledContent("Host", value: "\(OllamaConfig.host):\(OllamaConfig.port)")
                    TextField("Model", text: $ollamaModel)
                        .textFieldStyle(.roundedBorder)
                    Text("Browse and pull models in the Ollama Models tab.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Backend")
    }
}
