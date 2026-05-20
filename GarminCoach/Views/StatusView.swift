import SwiftUI

struct StatusView: View {
    @State private var status: ServerStatus? = nil
    @State private var isLoading = false
    @State private var error: String?
    @State private var lastUpdated: Date?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let updated = lastUpdated {
                        Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                            .font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    if isLoading {
                        ProgressView("Fetching Garmin data…").padding(.top, 60)
                    } else if let error {
                        errorCard(error)
                    } else if let s = status {
                        statusCards(s)
                    } else {
                        ContentUnavailableView(
                            "No Data",
                            systemImage: "waveform.path.ecg",
                            description: Text("Tap the refresh button to load today's metrics.")
                        ).padding(.top, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await load() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }.disabled(isLoading)
                }
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
                subtitle: r.level?.capitalized,
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
                subtitle: hrv.status.map { "\($0.capitalized)  ·  Baseline \(hrv.baselineLow ?? 0)–\(hrv.baselineHigh ?? 0)ms" },
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

        HStack(spacing: 12) {
            if let rhr = s.rhr {
                SmallMetricCard(icon: "heart.fill",  title: "RHR",    value: "\(rhr) bpm",   color: .red)
            }
            if let stress = s.stress {
                SmallMetricCard(icon: "brain.fill",   title: "Stress", value: "\(stress)",    color: stressColor(stress))
            }
            if let ts = s.trainingStatus {
                SmallMetricCard(icon: "figure.run",   title: "Status", value: ts.capitalized, color: .orange)
            }
        }
    }

    @ViewBuilder
    private func errorCard(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Error", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red).fontWeight(.semibold)
            Text(msg).foregroundStyle(.secondary).font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
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
        case 80...: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }

    private func batteryColor(_ level: Int?) -> Color {
        switch level ?? 0 {
        case 60...: return .green
        case 30..<60: return .yellow
        default: return .red
        }
    }

    private func hrvColor(_ status: String?) -> Color {
        switch status?.uppercased() {
        case "BALANCED": return .green
        case "UNBALANCED": return .orange
        default: return .red
        }
    }

    private func stressColor(_ stress: Int) -> Color {
        switch stress {
        case ..<26: return .green
        case 26..<51: return .yellow
        case 51..<76: return .orange
        default: return .red
        }
    }
}

// MARK: - Reusable components

struct MetricCard: View {
    let icon: String
    let title: String
    let value: String
    var unit: String = ""
    var subtitle: String? = nil
    var color: Color = .blue

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value).font(.title2).fontWeight(.semibold)
                    if !unit.isEmpty {
                        Text(unit).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let sub = subtitle {
                    Text(sub).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct SmallMetricCard: View {
    let icon: String
    let title: String
    let value: String
    var color: Color = .blue

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.callout).fontWeight(.semibold)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
