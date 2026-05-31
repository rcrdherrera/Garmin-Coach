import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var serverURL    = ""
    @State private var serverToken  = ""
    @State private var savedURL     = ""
    @State private var savedToken   = ""
    @State private var isSaved      = false
    @State private var isReachable: Bool? = nil
    @State private var checking     = false

    private var hasUnsavedChanges: Bool {
        serverURL.trimmingCharacters(in: .whitespacesAndNewlines) != savedURL ||
        serverToken.trimmingCharacters(in: .whitespaces) != savedToken
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://100.x.x.x:8765", text: $serverURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                } header: {
                    Text("Server URL")
                } footer: {
                    Text("Your home server address. Use the Tailscale IP so it works anywhere.")
                }

                Section {
                    SecureField("Secret token", text: $serverToken)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Server Token")
                } footer: {
                    Text("The COACH_SERVER_TOKEN you set in start_server.ps1.")
                }

                Section {
                    Button("Save") {
                        let url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        let tok = serverToken.trimmingCharacters(in: .whitespaces)
                        KeychainHelper.saveServerURL(url)
                        KeychainHelper.saveServerToken(tok)
                        savedURL = url
                        savedToken = tok
                        isSaved = true
                        isReachable = nil
                    }
                    .foregroundStyle(Color.brutalRed)
                    .disabled(serverURL.isEmpty || serverToken.isEmpty)

                    if isSaved {
                        Button("Test Connection") {
                            Task { await testConnection() }
                        }
                        .foregroundStyle(Color.brutalRed)
                        .disabled(checking || hasUnsavedChanges)

                        if checking {
                            HStack {
                                ProgressView().scaleEffect(0.8)
                                Text("Checking…").foregroundStyle(.secondary)
                            }
                        } else if let ok = isReachable {
                            Label(
                                ok ? "Server reachable" : "Cannot reach server",
                                systemImage: ok ? "checkmark.circle.fill" : "xmark.circle.fill"
                            )
                            .foregroundStyle(ok ? .green : .brutalRed)
                        }

                        Button("Remove Config", role: .destructive) {
                            KeychainHelper.deleteServerConfig()
                            isSaved = false
                            isReachable = nil
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Coaching Engine", value: "Claude Opus 4.8 (server-side)")
                    LabeledContent("Garmin Data", value: "Live API + SQLite history")
                    LabeledContent("Version", value: "2.0")
                }
            }
            .navigationTitle("SETTINGS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundStyle(Color.brutalRed)
                }
            }
            .onAppear {
                isSaved = KeychainHelper.hasServerConfig()
                serverURL   = KeychainHelper.loadServerURL()   ?? ""
                serverToken = KeychainHelper.loadServerToken() ?? ""
                savedURL    = serverURL
                savedToken  = serverToken
            }
        }
        .preferredColorScheme(.dark)
    }

    private func testConnection() async {
        checking = true
        isReachable = await ServerClient.shared.isReachable()
        checking = false
    }
}
