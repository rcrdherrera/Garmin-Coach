import SwiftUI
import Charts

// MARK: - Recovery Ring Card (hero section)

struct RecoveryRingCard: View {
    let status: ServerStatus

    private var score: Int { status.readiness?.score ?? 0 }
    private var level: String { status.readiness?.level?.capitalized ?? "" }

    private var ringColor: Color {
        switch score {
        case 80...: return .green
        case 60..<80: return .teal
        case 40..<60: return .yellow
        default: return .red
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(ringColor.opacity(0.15), lineWidth: 16)
                    .frame(width: 180, height: 180)

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 180, height: 180)
                    .animation(.easeInOut(duration: 0.8), value: score)

                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(ringColor)
                    Text("RECOVERY")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .tracking(2)
                }
            }
            .padding(.top, 4)

            if !level.isEmpty {
                Text(level)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ringColor)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(ringColor.opacity(0.12), in: Capsule())
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private func ringStatItem(label: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value).font(.title3.weight(.bold))
                if !unit.isEmpty {
                    Text(unit).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .tracking(0.5)
        }
    }
}

// MARK: - Body Battery Card

struct BodyBatteryCard: View {
    let battery: ServerStatus.BodyBattery

    private var level: Int { battery.current ?? 0 }
    private var color: Color {
        switch level {
        case 60...: return .green
        case 30..<60: return .yellow
        default: return .red
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Gauge arc (bottom semicircle)
                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .stroke(color.opacity(0.15), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0.25, to: 0.25 + Double(level) / 100 * 0.5)
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .frame(width: 72, height: 72)
                    .animation(.easeInOut(duration: 0.8), value: level)

                Text("\(level)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(color)
            }

            VStack(spacing: 2) {
                Text("BODY BATTERY")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                    .multilineTextAlignment(.center)
                Text("↑\(battery.high ?? 0)  ↓\(battery.low ?? 0)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Sleep Card

struct SleepCard: View {
    let sleep: ServerStatus.Sleep

    private var score: Int { sleep.score ?? 0 }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.indigo.opacity(0.15), lineWidth: 10)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: Double(score) / 100)
                    .stroke(Color.indigo, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 60, height: 60)
                    .animation(.easeInOut(duration: 0.8), value: score)

                Text("\(score)")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.indigo)
            }

            VStack(spacing: 2) {
                Text("SLEEP")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                if let dur = sleep.durationH {
                    Text(String(format: "%.1fh", dur))
                        .font(.callout.weight(.semibold))
                }
                HStack(spacing: 6) {
                    if let deep = sleep.deepH {
                        Text("D \(String(format: "%.1fh", deep))")
                    }
                    if let rem = sleep.remH {
                        Text("R \(String(format: "%.1fh", rem))")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - HRV Context Card

struct HRVContextCard: View {
    let hrv: ServerStatus.HRVData

    private var statusColor: Color {
        switch hrv.status?.uppercased() {
        case "BALANCED":   return .green
        case "UNBALANCED": return .orange
        default:           return .red
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .foregroundStyle(statusColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 3) {
                Text("HRV Context")
                    .font(.caption.weight(.semibold))
                HStack(spacing: 12) {
                    if let weekly = hrv.weeklyAvg {
                        Text("7-day avg: \(weekly) ms").font(.caption2).foregroundStyle(.secondary)
                    }
                    if let low = hrv.baselineLow, let high = hrv.baselineHigh {
                        Text("Baseline: \(low)–\(high) ms").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if let status = hrv.status {
                Text(status.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.12), in: Capsule())
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            Text("TRENDS")
                .font(.caption)
                .foregroundStyle(.secondary)
                .tracking(1)
                .padding(.horizontal, 4)

            if !hrvData.isEmpty {
                TrendCard(
                    title: "HRV",
                    value: snapshots.last?.hrv.map { "\($0) ms" } ?? "—",
                    data: hrvData,
                    color: .green
                )
            }
            if !sleepData.isEmpty {
                TrendCard(
                    title: "Sleep Score",
                    value: snapshots.last?.sleepScore.map { "\($0)" } ?? "—",
                    data: sleepData,
                    color: .indigo
                )
            }
            if !bbData.isEmpty {
                TrendCard(
                    title: "Body Battery",
                    value: snapshots.last?.bodyBatteryHigh.map { "\($0)" } ?? "—",
                    data: bbData,
                    color: .yellow
                )
            }
            if !rhrData.isEmpty {
                TrendCard(
                    title: "Resting HR",
                    value: snapshots.last?.rhr.map { "\($0) bpm" } ?? "—",
                    data: rhrData,
                    color: .red
                )
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
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(value)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(width: 100, alignment: .leading)

            Spacer()

            SparklineChart(data: data, color: color)
                .frame(width: 110, height: 44)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Sparkline Chart

struct SparklineChart: View {
    let data: [Double]
    let color: Color

    private struct Point: Identifiable {
        let id: Int
        let value: Double
    }

    private var points: [Point] {
        data.enumerated().map { Point(id: $0.offset, value: $0.element) }
    }

    var body: some View {
        Group {
            if points.count < 2 {
                RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.1))
            } else {
                Chart(points) { pt in
                    AreaMark(
                        x: .value("Day", pt.id),
                        y: .value("Value", pt.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Day", pt.id),
                        y: .value("Value", pt.value)
                    )
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

// MARK: - HR Zones Chart

struct HRZonesChart: View {
    let z1s: Double?
    let z2s: Double?
    let z3s: Double?
    let z4s: Double?
    let z5s: Double?

    private struct Zone: Identifiable {
        let id: String
        let minutes: Double
        let color: Color
    }

    private var zones: [Zone] {
        [
            Zone(id: "Z1", minutes: (z1s ?? 0) / 60, color: .blue.opacity(0.7)),
            Zone(id: "Z2", minutes: (z2s ?? 0) / 60, color: .teal),
            Zone(id: "Z3", minutes: (z3s ?? 0) / 60, color: .yellow),
            Zone(id: "Z4", minutes: (z4s ?? 0) / 60, color: .orange),
            Zone(id: "Z5", minutes: (z5s ?? 0) / 60, color: .red),
        ].filter { $0.minutes > 0.1 }
    }

    var body: some View {
        Group {
            if zones.isEmpty {
                Text("No HR zone data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart(zones) { zone in
                    BarMark(
                        x: .value("Minutes", zone.minutes),
                        y: .value("Zone", zone.id)
                    )
                    .foregroundStyle(zone.color)
                    .annotation(position: .trailing, alignment: .leading, spacing: 6) {
                        Text(String(format: "%.0fm", zone.minutes))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: CGFloat(zones.count) * 38)
            }
        }
    }
}
