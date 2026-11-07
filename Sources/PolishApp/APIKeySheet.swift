import SwiftUI

/// Popup dialog for entering/replacing the API key.
struct APIKeySheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.hasStoredKey ? "Replace API Key" : "Set API Key")
                .font(.headline)

            SecureField("Paste your API key", text: $model.apiKeyInput)
                .textFieldStyle(.roundedBorder)
                .onSubmit { save() }

            Text("Saved to ~/.config/polish/api-key (readable only by you).")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    model.apiKeyInput = ""
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func save() {
        if model.saveKey() {
            dismiss()
        }
    }
}
