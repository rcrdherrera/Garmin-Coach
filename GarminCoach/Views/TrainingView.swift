import SwiftUI
import SwiftData

// MARK: - Training tab (Activity list + embedded Analyze)

struct TrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CachedActivity.startTimeLocal, order: .reverse) private var activities: [CachedActivity]

    @State private var isLoading    = false
    @State private var showAnalyze  = false
    @State private var typeFilter: ActivityTypeFilter = .all

    enum ActivityTypeFilter: String, CaseIterable {
        case all      = "All"
        case runs     = "Runs"
        case strength = "Strength"
        case other    = "Other"

        var activityTypeParam: String? {
            switch self {
            case .all:      return nil
            case .runs:     return "running"
            case .strength: return "strength_training"
            case .other:    return nil   // handled client-side by exclusion
            }
        }

        func matches(_ type: String) -> Bool {
            switch self {
            case .all: return true
            case .runs: return type.contains("running") || type.contains("treadmill") || type.contains("track")
            case .strength: return type.contains("strength") || type.contains("fitness_equipment")
            case .other: return !ActivityTypeFilter.runs.matches(type) && !ActivityTypeFilter.strength.matches(type)
            }
        }
    }

    private var filtered: [CachedActivity] {
        activities.filter { typeFilter.matches($0.type) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterChips

                Group {
                    if filtered.isEmpty && isLoading {
                        LoadingCard(message: "Loading activities…").padding()
                    } else if filtered.isEmpty {
                        emptyView
                    } else {
                        activityList
                    }
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("TRAINING")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showAnalyze = true } label: {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .foregroundStyle(Color.brutalRed)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await forceSync() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(isLoading ? Color.white.opacity(0.3) : Color.white.opacity(0.7))
                    }
                    .disabled(isLoading)
                }
            }
            .sheet(isPresented: $showAnalyze) {
                NavigationStack {
                    AnalyzeView(presetActivityType: typeFilter.activityTypeParam)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showAnalyze = false }
                                    .foregroundStyle(Color.brutalRed)
                            }
                        }
                }
                .preferredColorScheme(.dark)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await CacheManager.shared.syncActivitiesIfNeeded(context: modelContext)
        }
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ActivityTypeFilter.allCases, id: \.self) { f in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { typeFilter = f }
                    } label: {
                        Text(f.rawValue.uppercased())
                            .font(.system(size: 11, weight: .black))
                            .tracking(0.5)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                typeFilter == f ? Color.brutalRed : Color(white: 0.12),
                                in: RoundedRectangle(cornerRadius: 4)
                            )
                            .foregroundStyle(typeFilter == f ? .white : Color.white.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(typeFilter == f ? Color.clear : Color.brutalBorder, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color.black)
        .overlay(alignment: .bottom) { Divider().background(Color.brutalBorder) }
    }

    // MARK: - Activity list

    private var activityList: some View {
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

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 12) {
            Text("NO ACTIVITIES")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(Color.white.opacity(0.1))
            Text("Tap ↻ to sync your training history.")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Grouping (same as ActivityListView)

    private var groupedByWeek: [(String, [CachedActivity])] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2

        let grouped = Dictionary(grouping: filtered) { activity -> String in
            let date = parseDate(activity.startTimeLocal)
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return String(format: "%04d-W%02d", comps.yearForWeekOfYear ?? 0, comps.weekOfYear ?? 0)
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
        comps.weekOfYear = week; comps.yearForWeekOfYear = year; comps.weekday = 2
        guard let weekStart = calendar.date(from: comps) else { return key }
        let now = Date()
        let nowComps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        var thisComps = DateComponents()
        thisComps.weekOfYear = nowComps.weekOfYear
        thisComps.yearForWeekOfYear = nowComps.yearForWeekOfYear
        thisComps.weekday = 2
        if let thisWeek = calendar.date(from: thisComps) {
            if calendar.isDate(weekStart, equalTo: thisWeek, toGranularity: .day) { return "This Week" }
            if let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek),
               calendar.isDate(weekStart, equalTo: lastWeek, toGranularity: .day) { return "Last Week" }
        }
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return "\(Self._weekRangeFormatter.string(from: weekStart)) – \(Self._weekRangeFormatter.string(from: weekEnd))"
    }

    private static let _weekRangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let _dateParser1: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
    private static let _dateParser2: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f
    }()

    private func parseDate(_ str: String) -> Date {
        let trimmed = String(str.prefix(19))
        return Self._dateParser1.date(from: trimmed)
            ?? Self._dateParser2.date(from: trimmed)
            ?? Date()
    }

    // MARK: - Sync

    private func forceSync() async {
        isLoading = true
        defer { isLoading = false }
        await CacheManager.shared.forceSyncActivities(context: modelContext)
    }
}
