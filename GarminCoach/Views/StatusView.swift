import SwiftUI
import SwiftData

struct StatusView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailySnapshot.date, order: .reverse) private var snapshots: [DailySnapshot]
    @Query(sort: \CachedActivity.startTimeLocal, order: .reverse) private var activities: [CachedActivity]

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
                VStack(spacing: 12) {
                    if let updated = lastUpdated {
                        Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.25))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    if isLoading && status == nil {
                        loadingView
                    } else if let err = error, status == nil {
                        errorView(err)
                    } else if let s = status {
                        mainContent(s)
                    } else {
                        emptyView
                    }
                }
                .padding()
            }
            .background(Color.brutalBackground.ignoresSafeArea())
            .navigationTitle("TODAY")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await load()
                            await CacheManager.shared.syncTrendsIfNeeded(context: modelContext)
                            await CacheManager.shared.syncActivitiesIfNeeded(context: modelContext)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(isLoading ? Color.white.opacity(0.3) : Color.brutalRed)
                    }
                    .disabled(isLoading)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await load()
            await CacheManager.shared.syncTrendsIfNeeded(context: modelContext)
            await CacheManager.shared.syncActivitiesIfNeeded(context: modelContext)
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.brutalRed)
            Text("FETCHING GARMIN DATA")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.4))
                .tracking(1.5)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color.brutalRed)
                    .frame(width: 3)
                Text(msg)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brutalRed.opacity(0.4), lineWidth: 1))

            if !trendSnapshots.isEmpty { TrendsSection(snapshots: trendSnapshots) }
            chartsSection
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("NO DATA")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(Color.white.opacity(0.2))
                Text("Tap refresh to load today's metrics.")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .padding(40)

            if !trendSnapshots.isEmpty { TrendsSection(snapshots: trendSnapshots) }
            chartsSection
        }
    }

    @ViewBuilder
    private func mainContent(_ s: ServerStatus) -> some View {
        RecoveryRingCard(status: s)

        if s.bodyBattery != nil || s.sleep != nil {
            HStack(spacing: 10) {
                if let bb = s.bodyBattery { BodyBatteryCard(battery: bb) }
                if let sleep = s.sleep    { SleepCard(sleep: sleep) }
            }
        }

        HStack(spacing: 8) {
            if let stress = s.stress {
                brutalSmallCard(label: "STRESS", value: "\(stress)", color: stressColor(stress))
            }
            if let ts = s.trainingStatus {
                brutalSmallCard(label: "STATUS", value: ts.uppercased(), color: .orange)
            }
        }

        if let hrv = s.hrv, hrv.baselineLow != nil || hrv.weeklyAvg != nil {
            HRVContextCard(hrv: hrv)
        }

        sectionDivider("PERFORMANCE CHARTS")
        chartsSection

        if !trendSnapshots.isEmpty {
            sectionDivider("14-DAY TRENDS")
            TrendsSection(snapshots: trendSnapshots)
        }
    }

    private var chartsSection: some View {
        VStack(spacing: 12) {
            WeeklyMileageCard(activities: Array(activities))
            HRZonesAggregateCard(activities: Array(activities))
        }
    }

    private func sectionDivider(_ label: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.brutalRed)
                .frame(width: 3, height: 14)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.4))
                .tracking(1.5)
            Spacer()
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func brutalSmallCard(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .black))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.4))
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brutalBorder, lineWidth: 1))
    }

    // MARK: - Helpers

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
        default:      return .brutalRed
        }
    }
}
