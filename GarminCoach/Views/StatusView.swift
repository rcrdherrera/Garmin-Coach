import SwiftUI
import SwiftData

struct StatusView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailySnapshot.date, order: .reverse) private var snapshots: [DailySnapshot]

    @State private var status: ServerStatus?
    @State private var isLoading = false
    @State private var error: String?
    @State private var lastUpdated: Date?
    @State private var showSettings = false

    private var trendSnapshots: [DailySnapshot] {
        Array(snapshots.prefix(14)).reversed()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let updated = lastUpdated {
                        Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    if isLoading && status == nil {
                        LoadingCard(message: "Fetching Garmin data…")
                    } else if let err = error, status == nil {
                        VStack(spacing: 16) {
                            ErrorCard(message: err)
                            if !trendSnapshots.isEmpty {
                                TrendsSection(snapshots: trendSnapshots)
                            }
                        }
                    } else if let s = status {
                        // Hero: Recovery Ring
                        RecoveryRingCard(status: s)

                        // Body Battery + Sleep
                        if s.bodyBattery != nil || s.sleep != nil {
                            HStack(spacing: 12) {
                                if let bb = s.bodyBattery {
                                    BodyBatteryCard(battery: bb)
                                }
                                if let sleep = s.sleep {
                                    SleepCard(sleep: sleep)
                                }
                            }
                        }

                        // Stress + Training Status
                        HStack(spacing: 8) {
                            if let stress = s.stress {
                                SmallMetricCard(
                                    icon: "brain.fill",
                                    title: "Stress",
                                    value: "\(stress)",
                                    color: stressColor(stress)
                                )
                            }
                            if let ts = s.trainingStatus {
                                SmallMetricCard(
                                    icon: "figure.run",
                                    title: "Status",
                                    value: ts,
                                    color: .orange
                                )
                            }
                        }

                        // HRV context (baseline + status)
                        if let hrv = s.hrv, hrv.baselineLow != nil || hrv.weeklyAvg != nil {
                            HRVContextCard(hrv: hrv)
                        }

                        // 14-day trends from cache
                        if !trendSnapshots.isEmpty {
                            TrendsSection(snapshots: trendSnapshots)
                        }
                    } else {
                        ContentUnavailableView(
                            "No Data",
                            systemImage: "waveform.path.ecg",
                            description: Text("Tap refresh to load today's metrics.")
                        )
                        .padding(.top, 40)

                        if !trendSnapshots.isEmpty {
                            TrendsSection(snapshots: trendSnapshots)
                        }
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
        .task {
            await load()
            await CacheManager.shared.syncTrendsIfNeeded(context: modelContext)
        }
    }

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

    private func stressColor(_ stress: Int) -> Color {
        switch stress {
        case ..<26:   return .green
        case 26..<51: return .yellow
        case 51..<76: return .orange
        default:      return .red
        }
    }
}
