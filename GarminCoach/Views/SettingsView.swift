import SwiftUI

struct SettingsView: View {
    @State private var apiKey = ""
    @State private var isKeyHidden = true
    @State private var keyIsSaved = false
    @State private var showSavedAlert = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Group {
                            if isKeyHidden {
                                SecureField("sk-ant-api03-…", text: $apiKey)
                            } else {
                                TextField("sk-ant-api03-…", text: $apiKey)
                            }
                        }
                        .focused($fieldFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") { fieldFocused = false }
                            }
                        }

                        Button {
                            isKeyHidden.toggle()
                        } label: {
                            Image(systemName: isKeyHidden ? "eye" : "eye.slash")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button("Save Key") {
                        KeychainHelper.saveAPIKey(apiKey)
                        apiKey = ""
                        keyIsSaved = true
                        showSavedAlert = true
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Stored in the iOS Keychain. Never transmitted except to api.anthropic.com.")
                }

                if keyIsSaved {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("API key saved")
                        }

                        Button("Remove Key", role: .destructive) {
                            KeychainHelper.deleteAPIKey()
                            keyIsSaved = false
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Model", value: "Claude Opus 4.7")
                    LabeledContent("Data Source", value: "Apple Health")
                    LabeledContent("Version", value: "1.0")
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear {
            keyIsSaved = KeychainHelper.hasAPIKey()
        }
        .alert("Saved", isPresented: $showSavedAlert) {
            Button("OK") {}
        } message: {
            Text("API key saved to Keychain.")
        }
    }
}
