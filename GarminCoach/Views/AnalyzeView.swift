import SwiftUI

// MARK: - Mode

enum AnalyzeMode: String, CaseIterable {
    case day    = "Day"
    case week   = "Week"
    case month  = "Month"
    case custom = "Custom"

    var icon: String {
        switch self {
        case .day:    return "calendar"
        case .week:   return "calendar.badge.clock"
        case .month:  return "calendar.badge.plus"
        case .custom: return "slider.horizontal.3"
        }
    }
}

// MARK: - View

struct AnalyzeView: View {
    // Mode & date selections
    @State private var mode: AnalyzeMode = .week
    @State private var selectedDay   = Date()
    @State private var selectedWeekRef = Date()
    @State private var selectedMonth = Date()
    @State private var customStart: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var customEnd     = Date()

    // Results
    @State private var report        = ""
    @State private var analyzedLabel = ""
    @State private var isLoading     = false
    @State private var error: String?
    @State private var lastUpdated: Date?

    // MARK: Computed period

    private var periodString: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        switch mode {
        case .day:
            return df.string(from: selectedDay)
        case .week:
            let (mon, sun) = weekRange(for: selectedWeekRef)
            return "\(df.string(from: mon)):\(df.string(from: sun))"
        case .month:
            let mf = DateFormatter(); mf.dateFormat = "yyyy-MM"
            return mf.string(from: selectedMonth)
        case .custom:
            return "\(df.string(from: customStart)):\(df.string(from: customEnd))"
        }
    }

    private var periodDisplayLabel: String {
        switch mode {
        case .day:
            return selectedDay.formatted(date: .abbreviated, time: .omitted)
        case .week:
            let (mon, sun) = weekRange(for: selectedWeekRef)
            let m = mon.formatted(.dateTime.month(.abbreviated).day())
            let s = sun.formatted(.dateTime.month(.abbreviated).day().year())
            return "\(m) – \(s)"
        case .month:
            return selectedMonth.formatted(.dateTime.month(.wide).year())
        case .custom:
            let s = customStart.formatted(date: .abbreviated, time: .omitted)
            let e = customEnd.formatted(date: .abbreviated, time: .omitted)
            return "\(s) – \(e)"
        }
    }

    private func weekRange(for date: Date) -> (Date, Date) {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let weekday = cal.component(.weekday, from: date)
        let daysFromMonday = (weekday + 5) % 7
        let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: date)!
        let sunday = cal.date(byAdding: .day,  value: 6, to: monday)!
        return (monday, sunday)
    }

    private var canAnalyze: Bool {
        mode != .custom || customEnd >= customStart
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    modePicker
                    dateCard
                    Divider().padding(.horizontal)

                    if isLoading {
                        LoadingCard(message: "Analyzing \(periodDisplayLabel)…")
                    } else if let err = error {
                        ErrorCard(message: err)
                    } else if !report.isEmpty {
                        reportView
                    } else {
                        ContentUnavailableView(
                            "No Analysis",
                            systemImage: "chart.bar.xaxis",
                            description: Text("Select a period and tap Analyze.")
                        )
                        .padding(.top, 20)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Analyze")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await analyze() } } label: {
                        if isLoading { ProgressView().scaleEffect(0.8) }
                        else { Label("Analyze", systemImage: "chart.bar.doc.horizontal") }
                    }
                    .disabled(isLoading || !canAnalyze)
                }
            }
        }
    }

    // MARK: Mode Picker

    private var modePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AnalyzeMode.allCases, id: \.self) { m in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            mode = m
                            clearResults()
                        }
                    } label: {
                        Label(m.rawValue, systemImage: m.icon)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                mode == m ? Color.accentColor : Color(.secondarySystemFill),
                                in: Capsule()
                            )
                            .foregroundStyle(mode == m ? .white : .primary)
                    }
                }
            }
        }
    }

    // MARK: Date Card

    @ViewBuilder
    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch mode {
            case .day:
                pickerRow(label: "Date", date: $selectedDay)

            case .week:
                pickerRow(label: "Any day in week", date: $selectedWeekRef)
                Label(periodDisplayLabel, systemImage: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .month:
                pickerRow(label: "Month", date: $selectedMonth)
                Text(periodDisplayLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .custom:
                pickerRow(label: "From", date: $customStart)
                Divider()
                pickerRow(label: "To", date: $customEnd)
                if customEnd < customStart {
                    Label("End date must be after start date", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func pickerRow(label: String, date: Binding<Date>) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            DatePicker("", selection: date, displayedComponents: .date)
                .labelsHidden()
        }
    }

    // MARK: Report

    private var reportView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(analyzedLabel, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let updated = lastUpdated {
                    Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Divider()

            Text(report)
                .font(.body)
                .lineSpacing(5)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Actions

    private func clearResults() {
        report = ""; error = nil; lastUpdated = nil; analyzedLabel = ""
    }

    private func analyze() async {
        isLoading = true; error = nil
        let label = periodDisplayLabel
        defer { isLoading = false }
        do {
            let resp = try await ServerClient.shared.analyze(period: periodString)
            report = resp.report
            analyzedLabel = label
            lastUpdated = .now
        } catch {
            self.error = error.localizedDescription
        }
    }
}
