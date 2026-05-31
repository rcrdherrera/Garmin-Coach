import SwiftUI
import Charts
import SwiftData

// MARK: - Design tokens

extension Color {
    static let brutalBackground = Color.black
    static let brutalCard       = Color(white: 0.08)
    static let brutalBorder     = Color.white.opacity(0.10)
    static let brutalRed        = Color(red: 1, green: 0.12, blue: 0.12)
    static let brutalRedSoft    = Color(red: 1, green: 0.12, blue: 0.12).opacity(0.15)
}

private func brutalCard<S: Shape>(_ shape: S) -> some View {
    shape
        .fill(Color.brutalCard)
        .overlay(shape.stroke(Color.brutalBorder, lineWidth: 1))
}

// MARK: - Recovery Ring Card

struct RecoveryRingCard: View {
    let status: ServerStatus

    private var score: Int? { status.readiness?.score }
    private var level: String { status.readiness?.level?.uppercased() ?? "" }

    private var ringColor: Color {
        guard let s = score else { return Color.white.opacity(0.2) }
        switch s {
        case 80...: return .green
        case 60..<80: return Color(red: 0.2, green: 0.8, blue: 0.6)
        case 40..<60: return .yellow
        default: return .brutalRed
        }
    }

    private var ringFill: CGFloat {
        guard let s = score else { return 0 }
        return CGFloat(s) / 100
    }

    private var recoveryDelta: String? {
        guard let high = status.bodyBattery?.high,
              let low  = status.bodyBattery?.low,
              high > low else { return nil }
        return "+\(high - low)"
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 16)
                    .frame(width: 180, height: 180)

                Circle()
                    .trim(from: 0, to: ringFill)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 180, height: 180)
                    .animation(.easeInOut(duration: 0.8), value: score)

                VStack(spacing: 4) {
                    if let s = score {
                        Text("\(s)")
                            .font(.system(size: 52, weight: .black, design: .default))
                            .foregroundStyle(ringColor)
                    } else {
                        Text("--")
                            .font(.system(size: 52, weight: .black, design: .default))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                    Text("RECOVERY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .tracking(2)
                    if let delta = recoveryDelta {
                        Text(delta)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding(.top, 4)

            if !level.isEmpty {
                Text(level)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(ringColor)
                    .tracking(1.5)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(ringColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            } else if score == nil {
                Text("AWAITING DATA")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .tracking(1.5)
            }

            HStack(spacing: 32) {
                if let hrv = status.hrv?.lastNight {
                    ringStatItem(label: "HRV", value: "\(hrv)", unit: "ms")
                }
                if let rhr = status.rhr {
                    ringStatItem(label: "RHR", value: "\(rhr)", unit: "bpm")
                }
                if let stress = status.stress {
                    ringStatItem(label: "STRESS", value: "\(stress)", unit: "")
                }
            }
        }
        .padding(20)
        .background(brutalCard(RoundedRectangle(cornerRadius: 10, style: .continuous)))
    }

    @ViewBuilder
    private func ringStatItem(label: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value).font(.system(size: 18, weight: .black))
                if !unit.isEmpty {
                    Text(unit).font(.caption2).foregroundStyle(Color.white.opacity(0.5))
                }
            }
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.4))
                .tracking(1)
        }
    }
}

// MARK: - Body Battery Card

struct BodyBatteryCard: View {
    let battery: ServerStatus.BodyBattery

    private var level: Int? { battery.current }
    private var color: Color {
        guard let l = level else { return Color.white.opacity(0.2) }
        switch l {
        case 60...: return .green
        case 30..<60: return .yellow
        default: return .brutalRed
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0.25, to: 0.25 + Double(level ?? 0) / 100 * 0.5)
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .frame(width: 72, height: 72)
                    .animation(.easeInOut(duration: 0.8), value: level)

                if let l = level {
                    Text("\(l)")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(color)
                } else {
                    Text("--")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
            }

            VStack(spacing: 2) {
                Text("BODY BATTERY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .tracking(0.5)
                    .multilineTextAlignment(.center)
                if let h = battery.high, let l = battery.low {
                    Text("H \(h)  L \(l)")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.3))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(brutalCard(RoundedRectangle(cornerRadius: 10, style: .continuous)))
    }
}

// MARK: - Sleep Card

struct SleepCard: View {
    let sleep: ServerStatus.Sleep

    private var score: Int? { sleep.score }

    private var scoreColor: Color {
        guard let s = score else { return Color.white.opacity(0.2) }
        switch s {
        case 80...: return .green
        case 60..<80: return Color(red: 0.2, green: 0.8, blue: 0.6)
        case 40..<60: return .yellow
        default: return .brutalRed
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 10)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: Double(score ?? 0) / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 60, height: 60)
                    .animation(.easeInOut(duration: 0.8), value: score)

                if let s = score {
                    Text("\(s)")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(scoreColor)
                } else {
                    Text("--")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
            }

            VStack(spacing: 2) {
                Text("SLEEP")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .tracking(0.5)
                if let dur = sleep.durationH, dur > 0 {
                    Text(String(format: "%.1fh", dur))
                        .font(.callout.weight(.bold))
                } else {
                    Text("--")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                HStack(spacing: 6) {
                    if let deep = sleep.deepH, deep > 0 {
                        Text("D \(String(format: "%.1fh", deep))")
                    }
                    if let rem = sleep.remH, rem > 0 {
                        Text("R \(String(format: "%.1fh", rem))")
                    }
                }
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(brutalCard(RoundedRectangle(cornerRadius: 10, style: .continuous)))
    }
}

// MARK: - HRV Context Card

struct HRVContextCard: View {
    let hrv: ServerStatus.HRVData

    private var statusColor: Color {
        switch hrv.status?.uppercased() {
        case "BALANCED":   return .green
        case "UNBALANCED": return .orange
        default:           return .brutalRed
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .foregroundStyle(statusColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 3) {
                Text("HRV CONTEXT")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .tracking(1)
                HStack(spacing: 12) {
                    if let weekly = hrv.weeklyAvg {
                        Text("7-day avg: \(weekly) ms").font(.caption2).foregroundStyle(Color.white.opacity(0.6))
                    }
                    if let low = hrv.baselineLow, let high = hrv.baselineHigh {
                        Text("Baseline: \(low)–\(high) ms").font(.caption2).foregroundStyle(Color.white.opacity(0.6))
                    }
                }
            }

            Spacer()

            if let status = hrv.status {
                Text(status.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(statusColor)
                    .tracking(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(14)
        .background(brutalCard(RoundedRectangle(cornerRadius: 10, style: .continuous)))
    }
}

// MARK: - Trends Section

struct TrendsSection: View {
    let snapshots: [DailySnapshot]

    private var hrvData: [Double] { snapshots.compactMap { $0.hrv.map { Double($0) } } }
    private var sleepData: [Double] { snapshots.compactMap { $0.sleepScore.map { Double($0) } } }
    private var bbData: [Double] { snapshots.compactMap { $0.bodyBatteryHigh.map { Double($0) } } }
    private var rhrData: [Double] { snapshots.compactMap { $0.rhr.map { Double($0) } } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("14-DAY TRENDS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.4))
                .tracking(1.5)
                .padding(.horizontal, 4)

            if !hrvData.isEmpty {
                TrendCard(title: "HRV", value: snapshots.last?.hrv.map { "\($0) ms" } ?? "—", data: hrvData, color: .green)
            }
            if !sleepData.isEmpty {
                TrendCard(title: "Sleep Score", value: snapshots.last?.sleepScore.map { "\($0)" } ?? "—", data: sleepData, color: Color(red: 0.4, green: 0.3, blue: 1))
            }
            if !bbData.isEmpty {
                TrendCard(title: "Body Battery", value: snapshots.last?.bodyBatteryHigh.map { "\($0)" } ?? "—", data: bbData, color: .yellow)
            }
            if !rhrData.isEmpty {
                TrendCard(title: "Resting HR", value: snapshots.last?.rhr.map { "\($0) bpm" } ?? "—", data: rhrData, color: .brutalRed)
            }
        }
    }
}

// MARK: - Trend Card

struct TrendCard: View {
    let title: String
    let value: String
    let data: [Double]
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .tracking(1)
                Text(value)
                    .font(.system(size: 18, weight: .black))
                    .lineLimit(1)
            }
            .frame(width: 100, alignment: .leading)

            Spacer()

            SparklineChart(data: data, color: color)
                .frame(width: 110, height: 44)
        }
        .padding(14)
        .background(brutalCard(RoundedRectangle(cornerRadius: 10, style: .continuous)))
    }
}

// MARK: - Sparkline Chart

struct SparklineChart: View {
    let data: [Double]
    let color: Color

    private struct Point: Identifiable { let id: Int; let value: Double }

    private var points: [Point] {
        data.enumerated().map { Point(id: $0.offset, value: $0.element) }
    }

    var body: some View {
        Group {
            if points.count < 2 {
                RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.1))
            } else {
                Chart(points) { pt in
                    AreaMark(x: .value("Day", pt.id), y: .value("Value", pt.value))
                        .foregroundStyle(LinearGradient(colors: [color.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Day", pt.id), y: .value("Value", pt.value))
                        .foregroundStyle(color)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartLegend(.hidden)
            }
        }
    }
}

// MARK: - HR Zones Chart (single-activity, used in ActivityDetailView)

struct HRZonesChart: View {
    let z1s: Double?
    let z2s: Double?
    let z3s: Double?
    let z4s: Double?
    let z5s: Double?

    private struct Zone: Identifiable {
        let id: String; let label: String; let minutes: Double; let pct: Double; let color: Color
    }

    private var zones: [Zone] {
        typealias Raw = (id: String, label: String, secs: Double, color: Color)
        let raw: [Raw] = [
            ("Z1", "Z1  <147",    z1s ?? 0, Color.white.opacity(0.3)),
            ("Z2", "Z2  147–162", z2s ?? 0, Color.teal),
            ("Z3", "Z3  163–173", z3s ?? 0, Color.yellow),
            ("Z4", "Z4  174–181", z4s ?? 0, Color.orange),
            ("Z5", "Z5  182+",    z5s ?? 0, Color.brutalRed),
        ]
        let total = raw.map { $0.secs }.reduce(0.0, +)
        let active = raw.filter { $0.secs > 0.1 }
        return active.map { r in
            let mins = r.secs / 60
            let pct  = total > 0 ? r.secs / total * 100 : 0
            return Zone(id: r.id, label: r.label, minutes: mins, pct: pct, color: r.color)
        }
    }

    var body: some View {
        Group {
            if zones.isEmpty {
                Text("No HR zone data")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.3))
            } else {
                Chart(zones) { zone in
                    BarMark(x: .value("Minutes", zone.minutes), y: .value("Zone", zone.label))
                        .foregroundStyle(zone.color)
                        .annotation(position: .trailing, alignment: .leading, spacing: 6) {
                            Text(String(format: "%.0fm · %.0f%%", zone.minutes, zone.pct))
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                }
                .chartXAxis(.hidden)
                .frame(height: CGFloat(zones.count) * 38)
            }
        }
    }
}

// MARK: - Weekly Mileage Card

enum ChartPeriod: String, CaseIterable {
    case sevenDays  = "7D"
    case oneMonth   = "1M"
    case threeMonths = "3M"
    case sixMonths  = "6M"
    case oneYear    = "1Y"

    var days: Int {
        switch self {
        case .sevenDays:   return 7
        case .oneMonth:    return 30
        case .threeMonths: return 90
        case .sixMonths:   return 180
        case .oneYear:     return 365
        }
    }
}

private struct WeekPoint: Identifiable {
    let id: String       // ISO week key "YYYY-WNN"
    let weekStart: Date
    let km: Double
}

struct WeeklyMileageCard: View {
    let activities: [CachedActivity]

    @State private var period: ChartPeriod = .threeMonths
    @State private var selectedWeek: String?

    private var cutoff: Date {
        Calendar.current.date(byAdding: .day, value: -period.days, to: .now) ?? .now
    }

    private var points: [WeekPoint] {
        let filtered = activities.filter { a in
            a.isRun && !a.startTimeLocal.isEmpty &&
            (parseDateFast(a.startTimeLocal) ?? .distantPast) >= cutoff
        }

        if filtered.isEmpty { return [] }

        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        var buckets: [String: (Date, Double)] = [:]
        for a in filtered {
            guard let d = parseDateFast(a.startTimeLocal) else { continue }
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)
            let key = "\(comps.yearForWeekOfYear ?? 0)-W\(String(format: "%02d", comps.weekOfYear ?? 0))"
            let monday = cal.date(from: comps) ?? d
            buckets[key, default: (monday, 0)].1 += a.distanceKm
        }
        return buckets
            .sorted { $0.key < $1.key }
            .map { WeekPoint(id: $0.key, weekStart: $0.value.0, km: $0.value.1) }
    }

    private var selectedPoint: WeekPoint? {
        guard let sel = selectedWeek else { return nil }
        return points.first { $0.id == sel }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WEEKLY MILEAGE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .tracking(1.5)
                    if let sel = selectedPoint {
                        Text(String(format: "%.1f km", sel.km))
                            .font(.system(size: 22, weight: .black))
                        Text(weekLabel(sel.weekStart))
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.4))
                    } else if let last = points.last {
                        Text(String(format: "%.1f km", last.km))
                            .font(.system(size: 22, weight: .black))
                        Text("this week")
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
                Spacer()
                periodPicker
            }

            if points.isEmpty {
                Text("No runs in this period — sync to populate")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.3))
                    .frame(height: 100, alignment: .center)
                    .frame(maxWidth: .infinity)
            } else if points.count >= 2 {
                Chart(points) { pt in
                    AreaMark(x: .value("Week", pt.weekStart), y: .value("km", pt.km))
                        .foregroundStyle(LinearGradient(
                            colors: [Color.brutalRed.opacity(0.25), .clear],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Week", pt.weekStart), y: .value("km", pt.km))
                        .foregroundStyle(Color.brutalRed)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Week", pt.weekStart), y: .value("km", pt.km))
                        .foregroundStyle(selectedWeek == pt.id ? Color.white : Color.brutalRed)
                        .symbolSize(selectedWeek == pt.id ? 60 : 25)
                    if let sel = selectedWeek, sel == pt.id {
                        RuleMark(x: .value("Week", pt.weekStart))
                            .foregroundStyle(Color.white.opacity(0.2))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { val in
                        AxisValueLabel {
                            if let v = val.as(Double.self) {
                                Text("\(Int(v))k")
                                    .font(.caption2)
                                    .foregroundStyle(Color.white.opacity(0.35))
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.08))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: strideCount)) { val in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(Color.white.opacity(0.35))
                            .font(.caption2)
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.05))
                    }
                }
                .chartXSelection(value: $selectedWeek.animation())
                .frame(height: 160)
            } else {
                Text("Only one run in this period — more data needed for a chart")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.3))
                    .frame(height: 100, alignment: .center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(brutalCard(RoundedRectangle(cornerRadius: 10, style: .continuous)))
    }

    private var strideCount: Int {
        switch period {
        case .sevenDays: return 1
        case .oneMonth: return 2
        case .threeMonths: return 4
        case .sixMonths: return 8
        case .oneYear: return 12
        }
    }

    private var periodPicker: some View {
        HStack(spacing: 4) {
            ForEach(ChartPeriod.allCases, id: \.self) { p in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { period = p; selectedWeek = nil }
                } label: {
                    Text(p.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(period == p ? .black : Color.white.opacity(0.5))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(period == p ? Color.white : Color.white.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }

    private func weekLabel(_ date: Date) -> String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: date) ?? date
        let fmt = DateFormatter(); fmt.dateFormat = "MMM d"
        return "\(fmt.string(from: date)) – \(fmt.string(from: end))"
    }

    private func parseDateFast(_ s: String) -> Date? {
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = s.count > 10 ? "yyyy-MM-dd'T'HH:mm:ss" : "yyyy-MM-dd"
        return df.date(from: String(s.prefix(19)))
    }
}

// MARK: - HR Zones Aggregate Card

struct HRZonesAggregateCard: View {
    let activities: [CachedActivity]

    @State private var period: ChartPeriod = .threeMonths
    @State private var selectedZoneId: String?

    private var cutoff: Date {
        Calendar.current.date(byAdding: .day, value: -period.days, to: .now) ?? .now
    }

    private struct ZoneData: Identifiable {
        let id: String; let label: String; let bpmRange: String
        let minutes: Double; let pct: Double; let color: Color
    }

    private var zoneData: [ZoneData] {
        let filtered = activities.filter { a in
            !a.startTimeLocal.isEmpty &&
            (parseDateFast(a.startTimeLocal) ?? .distantPast) >= cutoff
        }

        let z1 = filtered.compactMap { $0.hrZ1s }.reduce(0, +) / 60
        let z2 = filtered.compactMap { $0.hrZ2s }.reduce(0, +) / 60
        let z3 = filtered.compactMap { $0.hrZ3s }.reduce(0, +) / 60
        let z4 = filtered.compactMap { $0.hrZ4s }.reduce(0, +) / 60
        let z5 = filtered.compactMap { $0.hrZ5s }.reduce(0, +) / 60
        let total = z1 + z2 + z3 + z4 + z5

        guard total >= 1 else { return [] }

        func pct(_ v: Double) -> Double { total > 0 ? v / total * 100 : 0 }

        return [
            ZoneData(id: "Z1", label: "Z1", bpmRange: "<147",    minutes: z1, pct: pct(z1), color: Color.white.opacity(0.35)),
            ZoneData(id: "Z2", label: "Z2", bpmRange: "147–162", minutes: z2, pct: pct(z2), color: .teal),
            ZoneData(id: "Z3", label: "Z3", bpmRange: "163–173", minutes: z3, pct: pct(z3), color: .yellow),
            ZoneData(id: "Z4", label: "Z4", bpmRange: "174–181", minutes: z4, pct: pct(z4), color: .orange),
            ZoneData(id: "Z5", label: "Z5", bpmRange: "182+",    minutes: z5, pct: pct(z5), color: .brutalRed),
        ].filter { $0.minutes >= 0.1 }
    }

    private var hasZoneData: Bool { !zoneData.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HR ZONE DISTRIBUTION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .tracking(1.5)
                    if let sel = selectedZoneId, let z = zoneData.first(where: { $0.id == sel }) {
                        Text(z.label)
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(z.color)
                        Text("\(z.bpmRange) bpm  ·  \(String(format: "%.0fm  ·  %.0f%%", z.minutes, z.pct))")
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.4))
                    } else {
                        Text("Tap a bar")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(Color.white.opacity(0.2))
                    }
                }
                Spacer()
                periodPicker
            }

            if hasZoneData {
                Chart(zoneData) { z in
                    BarMark(x: .value("Minutes", z.minutes), y: .value("Zone", z.label))
                        .foregroundStyle(selectedZoneId == nil || selectedZoneId == z.id ? z.color : z.color.opacity(0.3))
                        .cornerRadius(3)
                        .annotation(position: .trailing, alignment: .leading, spacing: 6) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(z.bpmRange)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.35))
                                Text(String(format: "%.0fm · %.0f%%", z.minutes, z.pct))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                        }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { val in
                        AxisValueLabel {
                            if let s = val.as(String.self) {
                                Text(s)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 0).onChanged { val in
                                let origin = geo[proxy.plotFrame!].origin
                                let loc = CGPoint(x: val.location.x - origin.x, y: val.location.y - origin.y)
                                if let label: String = proxy.value(atY: loc.y) {
                                    selectedZoneId = label
                                }
                            }.onEnded { _ in
                                selectedZoneId = nil
                            })
                    }
                }
                .frame(height: CGFloat(zoneData.count) * 44)
            } else {
                Text("No HR zone data in this period — sync activities to populate")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.3))
                    .frame(height: 100, alignment: .center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(brutalCard(RoundedRectangle(cornerRadius: 10, style: .continuous)))
    }

    private var periodPicker: some View {
        HStack(spacing: 4) {
            ForEach(ChartPeriod.allCases, id: \.self) { p in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { period = p; selectedZoneId = nil }
                } label: {
                    Text(p.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(period == p ? .black : Color.white.opacity(0.5))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(period == p ? Color.white : Color.white.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }

    private func parseDateFast(_ s: String) -> Date? {
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = s.count > 10 ? "yyyy-MM-dd'T'HH:mm:ss" : "yyyy-MM-dd"
        return df.date(from: String(s.prefix(19)))
    }
}
