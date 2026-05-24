import SwiftUI

struct StatusView: View {
    @State private var status: ServerStatus?
    @State private var isLoading = false
    @State private var error: String?
    @State private var lastUpdated: Date?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if let updated = lastUpdated {
                        Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    if isLoading {
                        LoadingCard(message: "Fetching Garmin data…")
                    } else if let err = error {
                        ErrorCard(message: err)
                    } else if let s = status {
                        statusCards(s)
                    } else {
                        ContentUnavailableView(
                            "No Data",
                            systemImage: "waveform.path.ecg",
                            description: Text("Tap refresh to load today's metrics.")
                        )
                        .padding(.top, 40)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await load() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
        .task { await load() }
    }

    // MARK: - Cards

    @ViewBuilder
    private func statusCards(_ s: ServerStatus) -> some View {
        if let r = s.readiness {
            MetricCard(
                icon: "bolt.heart.fill",
                title: "Readiness",
                value: r.score.map { "\($0)" } ?? "—",
                unit: "/ 100",
                subtitle: [r.level?.capitalized, r.feedback].compactMap { $0 }.joined(separator: "  ·  ").nonEmpty,
                color: readinessColor(r.score)
            )
        }

        if let bb = s.bodyBattery {
            MetricCard(
                icon: "battery.100.bolt",
                title: "Body Battery",
                value: bb.current.map { "\($0)" } ?? "—",
                subtitle: "High \(bb.high ?? 0)  ·  Low \(bb.low ?? 0)",
                color: batteryColor(bb.current)
            )
        }

        if let hrv = s.hrv {
            MetricCard(
                icon: "waveform.path.ecg.rectangle",
                title: "HRV",
                value: hrv.lastNight.map { "\($0)" } ?? "—",
                unit: "ms",
                subtitle: [hrv.status?.capitalized, "Baseline \(hrv.baselineLow ?? 0)–\(hrv.baselineHigh ?? 0) ms"]
                    .compactMap { $0 }.joined(separator: "  ·  "),
                color: hrvColor(hrv.status)
            )
        }

        if let sleep = s.sleep {
            MetricCard(
                icon: "moon.zzz.fill",
                title: "Sleep",
                value: sleep.durationH.map { String(format: "%.1f", $0) } ?? "—",
                unit: "h",
                subtitle: "Deep \(sleep.deepH.map { String(format: "%.1fh", $0) } ?? "—")  ·  REM \(sleep.remH.map { String(format: "%.1fh", $0) } ?? "—")  ·  Score \(sleep.score ?? 0)",
                color: .indigo
            )
        }

        HStack(spacing: 10) {
            if let rhr = s.rhr {
                SmallMetricCard(icon: "heart.fill",  title: "RHR",    value: "\(rhr) bpm",   color: .red)
            }
            if let stress = s.stress {
                SmallMetricCard(icon: "brain.fill",  title: "Stress", value: "\(stress)",    color: stressColor(stress))
            }
            if let ts = s.trainingStatus {
                SmallMetricCard(icon: "figure.run",  title: "Status", value: ts.capitalized, color: .orange)
            }
        }
    }

    // MARK: - Load

    private func load() async {
        isLoading = true; error = nil
        defer { isLoading = false }
        do {
            status = try await ServerClient.shared.getStatus()
            lastUpdated = .now
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Colors

    private func readinessColor(_ score: Int?) -> Color {
        switch score ?? 0 {
        case 80...:   return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default:      return .red
        }
    }

    private func batteryColor(_ level: Int?) -> Color {
        switch level ?? 0 {
        case 60...:   return .green
        case 30..<60: return .yellow
        default:      return .red
        }
    }

    private func hrvColor(_ status: String?) -> Color {
        switch status?.uppercased() {
        case "BALANCED":   return .green
        case "UNBALANCED": return .orange
        default:           return .red
        }
    }

    private func stressColor(_ stress: Int) -> Color {
        switch stress {
        case ..<26:   return .green
        case 26..<51: return .yellow
        case 51..<76: return .orange
        default:      return .red
        }
    }
}

private extension String {
    var nonEmpty: Self? { isEmpty ? nil : self }
}
