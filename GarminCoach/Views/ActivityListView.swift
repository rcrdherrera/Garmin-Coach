import SwiftUI
import SwiftData

struct ActivityListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CachedActivity.startTimeLocal, order: .reverse) private var activities: [CachedActivity]

    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if activities.isEmpty && isLoading {
                    LoadingCard(message: "Loading activities…").padding()
                } else if activities.isEmpty {
                    VStack(spacing: 12) {
                        Text("NO ACTIVITIES")
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(Color.white.opacity(0.1))
                        Text("Tap refresh to load your training history.")
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(groupedByWeek, id: \.0) { label, acts in
                            Section(label) {
                                ForEach(acts) { activity in
                                    NavigationLink(destination: ActivityDetailView(activity: activity)) {
                                        ActivityRow(activity: activity)
                                    }
                                    .listRowBackground(Color(white: 0.08))
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.black)
                }
            }
            .navigationTitle("ACTIVITIES")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await forceSync() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(isLoading ? Color.white.opacity(0.3) : Color.brutalRed)
                    }
                    .disabled(isLoading)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await CacheManager.shared.syncActivitiesIfNeeded(context: modelContext)
        }
    }

    private func forceSync() async {
        isLoading = true
        defer { isLoading = false }
        await CacheManager.shared.forceSyncActivities(context: modelContext)
    }

    // MARK: - Grouping

    private var groupedByWeek: [(String, [CachedActivity])] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2  // Monday

        let grouped = Dictionary(grouping: activities) { activity -> String in
            let date = parseDate(activity.startTimeLocal)
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            let year = comps.yearForWeekOfYear ?? 0
            let week = comps.weekOfYear ?? 0
            return String(format: "%04d-W%02d", year, week)
        }

        return grouped
            .sorted { $0.key > $1.key }
            .map { key, acts in
                (weekLabel(for: key, calendar: cal), acts.sorted { $0.startTimeLocal > $1.startTimeLocal })
            }
    }

    private func weekLabel(for key: String, calendar: Calendar) -> String {
        let parts = key.split(separator: "-W")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let week = Int(parts[1]) else { return key }

        var comps = DateComponents()
        comps.weekOfYear = week
        comps.yearForWeekOfYear = year
        comps.weekday = 2  // Monday
        guard let weekStart = calendar.date(from: comps) else { return key }

        let now = Date()
        let nowComps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        var thisComps = DateComponents()
        thisComps.weekOfYear = nowComps.weekOfYear
        thisComps.yearForWeekOfYear = nowComps.yearForWeekOfYear
        thisComps.weekday = 2
        let thisWeekStart = calendar.date(from: thisComps)

        if let thisWeek = thisWeekStart {
            if calendar.isDate(weekStart, equalTo: thisWeek, toGranularity: .day) {
                return "This Week"
            }
            if let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek),
               calendar.isDate(weekStart, equalTo: lastWeek, toGranularity: .day) {
                return "Last Week"
            }
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return "\(fmt.string(from: weekStart)) – \(fmt.string(from: weekEnd))"
    }

    private func parseDate(_ str: String) -> Date {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        let trimmed = String(str.prefix(19))
        // Garmin DB uses space separator; try both formats
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let d = fmt.date(from: trimmed) { return d }
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return fmt.date(from: trimmed) ?? Date()
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let activity: CachedActivity

    private var accentColor: Color {
        activity.isRun ? Color.brutalRed : .teal
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 38, height: 38)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(accentColor.opacity(0.25), lineWidth: 1))
                Image(systemName: activity.activityIcon)
                    .foregroundStyle(accentColor)
                    .font(.callout)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.name)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    if activity.distanceKm > 0 {
                        Text(String(format: "%.1f km", activity.distanceKm))
                    }
                    Text(String(format: "%.0f min", activity.durationMin))
                    if let hr = activity.avgHR {
                        Text("\(hr) bpm")
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.45))
            }

            Spacer()

            if let load = activity.trainingLoad, load > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f", load))
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white)
                    Text("LOAD")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .tracking(0.5)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
