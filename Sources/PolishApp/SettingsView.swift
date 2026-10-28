import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Service") {
                LabeledContent("Status", value: model.statusMessage)
                LabeledContent("Accessibility", value: model.accessibilityTrusted ? "granted" : "missing")

                HStack {
                    Button(model.isRunning ? "Stop" : "Start") { model.toggle() }
                    Button("Refresh") { model.refreshSystemState() }
                    Spacer()
                    if !model.accessibilityTrusted {
                        Button("Grant Access…") { model.requestAccessibility() }
                        Button("Open Settings") { model.openAccessibilitySettings() }
                    }
                }
            }

            Section("LLM") {
                TextField("Provider", text: $model.config.provider)
                TextField("Model", text: $model.config.model)
                TextField("Base URL", text: $model.config.baseURL)
                TextField("reasoning_effort (e.g. off)", text: reasoningEffort)
            }

            Section("API Key") {
                HStack(spacing: 8) {
                    Image(systemName: model.hasStoredKey ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(model.hasStoredKey ? Color.green : Color.orange)
                    Text(model.hasStoredKey ? "Configured \(model.storedKeyHint ?? "")" : "Not configured")
                    Spacer()
                    if model.hasStoredKey {
                        Button("Remove", role: .destructive) { model.clearKey() }
                    }
                }

                HStack {
                    SecureField("Paste your API key", text: $model.apiKeyInput)
                        .onSubmit { model.saveKey() }
                    Button("Save") { model.saveKey() }
                }

                Text("Stored securely in your macOS keychain. The CLI can also read POLISH_API_KEY.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Hotkey & capture") {
                TextField("Hotkey", text: $model.config.hotkey)
                TextField("Max sentence length", value: $model.config.maxSentenceLength, format: .number)
                TextField("Clipboard restore delay (ms)", value: $model.config.clipboardRestoreDelayMS, format: .number)
                Toggle("Log raw LLM response", isOn: $model.config.logRawResponse)
            }

            Section("Prompt") {
                TextEditor(text: $model.config.prompt)
                    .frame(minHeight: 140)
                    .font(.body.monospaced())
            }

            Section("Log") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(model.logLines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(height: 120)
            }

            HStack {
                Spacer()
                Button("Save") { model.save() }
                    .keyboardShortcut("s")
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 640)
        .background(WindowAccessor())
        .onAppear { model.refreshSystemState() }
    }

    private var reasoningEffort: Binding<String> {
        Binding(
            get: { model.config.reasoningEffort ?? "" },
            set: { model.config.reasoningEffort = $0.isEmpty ? nil : $0 }
        )
    }
}
