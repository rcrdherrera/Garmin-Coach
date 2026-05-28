import SwiftUI

struct ActivityDetailView: View {
    let activity: CachedActivity

    @State private var evaluateReport: EvaluateResponse?
    @State private var isEvaluating = false
    @State private var evaluateError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                headerCard
                metricsGrid
                if activity.hrZ1s != nil || activity.hrZ2s != nil ||
                   activity.hrZ3s != nil || activity.hrZ4s != nil || activity.hrZ5s != nil {
                    hrZonesCard
                }
                evaluateCard
            }
            .padding()
        }
        .background(Color.brutalBackground.ignoresSafeArea())
        .navigationTitle(activity.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: activity.activityIcon)
                    .font(.title2)
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(.subheadline.weight(.medium))
                Text(activity.type.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.brutalBorder, lineWidth: 1))
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 10) {
            if activity.distanceKm > 0 {
                metricCell(
                    value: String(format: "%.2f", activity.distanceKm),
                    unit: "km", label: "Distance"
                )
            }
            metricCell(
                value: String(format: "%.0f", activity.durationMin),
                unit: "min", label: "Duration"
            )
            if let pace = activity.pacePerKm, activity.isRun {
                metricCell(value: pace, unit: "", label: "Pace")
            }
            if let hr = activity.avgHR {
                metricCell(value: "\(hr)", unit: "bpm", label: "Avg HR")
            }
            if let hr = activity.maxHR {
                metricCell(value: "\(hr)", unit: "bpm", label: "Max HR")
            }
            if let cad = activity.avgCadence, activity.isRun {
                metricCell(value: String(format: "%.0f", cad), unit: "spm", label: "Cadence")
            }
            if let te = activity.aerobicTE {
                metricCell(value: String(format: "%.1f", te), unit: "", label: "Aerobic TE")
            }
            if let load = activity.trainingLoad {
                metricCell(value: String(format: "%.0f", load), unit: "AU", label: "Load")
            }
            if let cal = activity.calories {
                metricCell(value: "\(cal)", unit: "kcal", label: "Calories")
            }
        }
    }

    @ViewBuilder
    private func metricCell(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.title3.weight(.semibold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if !unit.isEmpty {
                    Text(unit).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.brutalBorder, lineWidth: 1))
    }

    // MARK: - HR Zones

    private var hrZonesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HR ZONES")
                .font(.caption)
                .foregroundStyle(.secondary)
                .tracking(1)

            HRZonesChart(
                z1s: activity.hrZ1s,
                z2s: activity.hrZ2s,
                z3s: activity.hrZ3s,
                z4s: activity.hrZ4s,
                z5s: activity.hrZ5s
            )
        }
        .padding(16)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.brutalBorder, lineWidth: 1))
    }

    // MARK: - Evaluate

    @ViewBuilder
    private var evaluateCard: some View {
        if let report = evaluateReport {
            VStack(alignment: .leading, spacing: 10) {
                Text("EVALUATION")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Text(report.report)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.brutalBorder, lineWidth: 1))
        } else {
            VStack(spacing: 10) {
                if let err = evaluateError {
                    ErrorCard(message: err)
                }
                Button {
                    Task { await runEvaluate() }
                } label: {
                    HStack(spacing: 8) {
                        if isEvaluating { ProgressView().tint(.white).scaleEffect(0.8) }
                        else { Image(systemName: "chart.xyaxis.line") }
                        Text(isEvaluating ? "EVALUATING" : "EVALUATE THIS SESSION")
                            .font(.system(size: 12, weight: .black))
                            .tracking(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(Color.brutalRed, in: RoundedRectangle(cornerRadius: 8))
                }
                .disabled(isEvaluating)
            }
        }
    }

    // MARK: - Helpers

    private var accentColor: Color { activity.isRun ? Color.brutalRed : .teal }

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        if let date = fmt.date(from: String(activity.startTimeLocal.prefix(19))) {
            let out = DateFormatter()
            out.dateStyle = .long
            out.timeStyle = .short
            return out.string(from: date)
        }
        return activity.startTimeLocal
    }

    private func runEvaluate() async {
        isEvaluating = true
        evaluateError = nil
        defer { isEvaluating = false }
        do {
            evaluateReport = try await ServerClient.shared.evaluate(activityId: activity.activityId)
        } catch {
            evaluateError = error.localizedDescription
        }
    }
}
