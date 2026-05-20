import SwiftUI

struct SettingsView: View {
    @State private var serverURL  = ""
    @State private var serverToken = ""
    @State private var isSaved    = false
    @State private var isReachable: Bool? = nil
    @State private var checking = false

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
                        KeychainHelper.saveServerURL(serverURL.trimmingCharacters(in: .whitespacesAndNewlines))
                        KeychainHelper.saveServerToken(serverToken.trimmingCharacters(in: .whitespaces))
                        isSaved = true
                        isReachable = nil
                    }
                    .disabled(serverURL.isEmpty || serverToken.isEmpty)

                    if isSaved {
                        Button("Test Connection") {
                            Task { await testConnection() }
                        }
                        .disabled(checking)

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
                            .foregroundStyle(ok ? .green : .red)
                        }

                        Button("Remove Config", role: .destructive) {
                            KeychainHelper.deleteServerConfig()
                            isSaved = false
                            isReachable = nil
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Coaching Engine", value: "Claude Opus 4.7 (server-side)")
                    LabeledContent("Garmin Data", value: "Live API + SQLite history")
                    LabeledContent("Version", value: "2.0")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                isSaved = KeychainHelper.hasServerConfig()
                serverURL   = KeychainHelper.loadServerURL()   ?? ""
                serverToken = KeychainHelper.loadServerToken() ?? ""
            }
        }
    }

    private func testConnection() async {
        checking = true
        isReachable = await ServerClient.shared.isReachable()
        checking = false
    }
}
