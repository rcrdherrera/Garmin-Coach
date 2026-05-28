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
                    ContentUnavailableView(
                        "No Activities",
                        systemImage: "figure.run.circle",
                        description: Text("Tap refresh to load your training history.")
                    )
                } else {
                    List {
                        ForEach(groupedByWeek, id: \.0) { label, acts in
                            Section(label) {
                                ForEach(acts) { activity in
                                    NavigationLink(destination: ActivityDetailView(activity: activity)) {
                                        ActivityRow(activity: activity)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Activities")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await forceSync() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
        }
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
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt.date(from: String(str.prefix(19))) ?? Date()
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let activity: CachedActivity

    private var accentColor: Color {
        activity.isRun ? .orange : .purple
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: activity.activityIcon)
                    .foregroundStyle(accentColor)
                    .font(.callout)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

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
                .foregroundStyle(.secondary)
            }

            Spacer()

            if let load = activity.trainingLoad, load > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f", load))
                        .font(.caption.weight(.semibold))
                    Text("load")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
