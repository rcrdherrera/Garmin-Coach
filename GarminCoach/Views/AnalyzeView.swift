import SwiftUI

enum AnalyzeMode: String, CaseIterable {
    case day    = "Day"
    case week   = "Week"
    case month  = "Month"
    case custom = "Custom"
}

struct AnalyzeView: View {
    @State private var mode: AnalyzeMode? = nil
    @State private var selectedDay     = Date()
    @State private var selectedWeekRef = Date()
    @State private var selectedMonth   = Date()
    @State private var customStart: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var customEnd       = Date()

    @State private var report        = ""
    @State private var analyzedLabel = ""
    @State private var isLoading     = false
    @State private var error: String?
    @State private var lastUpdated: Date?

    // MARK: - Computed period

    private var periodString: String? {
        guard let mode else { return nil }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        switch mode {
        case .day:    return df.string(from: selectedDay)
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
        guard let mode else { return "" }
        switch mode {
        case .day:    return selectedDay.formatted(date: .abbreviated, time: .omitted)
        case .week:
            let (mon, sun) = weekRange(for: selectedWeekRef)
            return "\(mon.formatted(.dateTime.month(.abbreviated).day())) – \(sun.formatted(.dateTime.month(.abbreviated).day().year()))"
        case .month:  return selectedMonth.formatted(.dateTime.month(.wide).year())
        case .custom:
            return "\(customStart.formatted(date: .abbreviated, time: .omitted)) – \(customEnd.formatted(date: .abbreviated, time: .omitted))"
        }
    }

    private func weekRange(for date: Date) -> (Date, Date) {
        var cal = Calendar(identifier: .gregorian); cal.firstWeekday = 2
        let weekday = cal.component(.weekday, from: date)
        let daysFromMonday = (weekday + 5) % 7
        let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: date)!
        return (monday, cal.date(byAdding: .day, value: 6, to: monday)!)
    }

    private var canAnalyze: Bool {
        guard mode != nil else { return false }
        if mode == .custom { return customEnd >= customStart }
        return true
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    modePicker

                    if let mode {
                        dateCard(mode: mode)
                    }

                    if isLoading {
                        loadingCard
                    } else if let err = error {
                        errorCard(err)
                    } else if !report.isEmpty {
                        reportCard
                    } else {
                        emptyState
                    }
                }
                .padding()
            }
            .background(Color.brutalBackground.ignoresSafeArea())
            .navigationTitle("ANALYZE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await analyze() } } label: {
                        if isLoading {
                            ProgressView().scaleEffect(0.8).tint(.white)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "chart.bar.doc.horizontal")
                                Text("Analyze")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundStyle(canAnalyze ? Color.brutalRed : Color.white.opacity(0.3))
                        }
                    }
                    .disabled(isLoading || !canAnalyze)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        HStack(spacing: 6) {
            ForEach(AnalyzeMode.allCases, id: \.self) { m in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { mode = m; clearResults() }
                } label: {
                    Text(m.rawValue.uppercased())
                        .font(.system(size: 11, weight: .black))
                        .tracking(0.5)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            mode == m ? Color.brutalRed : Color(white: 0.1),
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                        .foregroundStyle(mode == m ? .white : Color.white.opacity(0.55))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(mode == m ? Color.clear : Color.brutalBorder, lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: - Date Card

    @ViewBuilder
    private func dateCard(mode: AnalyzeMode) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PERIOD SELECTION")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.35))
                .tracking(1.5)

            switch mode {
            case .day:
                pickerRow(label: "Date", date: $selectedDay)
            case .week:
                pickerRow(label: "Any day in week", date: $selectedWeekRef)
                Text(periodDisplayLabel)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.5))
            case .month:
                pickerRow(label: "Month", date: $selectedMonth)
                Text(periodDisplayLabel)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.5))
            case .custom:
                pickerRow(label: "From", date: $customStart)
                Divider().background(Color.brutalBorder)
                pickerRow(label: "To", date: $customEnd)
                if customEnd < customStart {
                    HStack(spacing: 6) {
                        Rectangle().fill(Color.orange).frame(width: 2, height: 12)
                        Text("End date must be after start date")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brutalBorder, lineWidth: 1))
    }

    private func pickerRow(label: String, date: Binding<Date>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.6))
            Spacer()
            DatePicker("", selection: date, displayedComponents: .date)
                .labelsHidden()
                .colorScheme(.dark)
        }
    }

    // MARK: - Loading

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView().progressViewStyle(.circular).tint(Color.brutalRed)
            Text("ANALYZING \(periodDisplayLabel.uppercased())")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.4))
                .tracking(1.5)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brutalBorder, lineWidth: 1))
    }

    // MARK: - Error

    private func errorCard(_ msg: String) -> some View {
        HStack(spacing: 10) {
            Rectangle().fill(Color.brutalRed).frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(msg)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                if msg.contains("No data") || msg.contains("empty") {
                    Text("Run the sync script to populate your database, then try again.")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
        }
        .padding(16)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brutalRed.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text(mode == nil ? "SELECT A PERIOD" : "NO ANALYSIS")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(Color.white.opacity(0.1))
            Text(mode == nil
                 ? "Choose Day, Week, Month, or Custom above."
                 : "Tap Analyze to generate your report.")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.35))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }

    // MARK: - Report Card

    private var reportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Rectangle().fill(Color.brutalRed).frame(width: 3, height: 14)
                    Text(analyzedLabel.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .tracking(1)
                }
                Spacer()
                if let updated = lastUpdated {
                    Text(updated.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.25))
                }
            }

            Divider().background(Color.brutalBorder)

            Text(report)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .lineSpacing(5)
                .foregroundStyle(Color.white.opacity(0.85))
        }
        .padding(16)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brutalBorder, lineWidth: 1))
    }

    // MARK: - Actions

    private func clearResults() { report = ""; error = nil; lastUpdated = nil; analyzedLabel = "" }

    private func analyze() async {
        guard let period = periodString else { return }
        isLoading = true; error = nil
        let label = periodDisplayLabel
        defer { isLoading = false }
        do {
            let resp = try await ServerClient.shared.analyze(period: period)
            report = resp.report
            analyzedLabel = label
            lastUpdated = .now
        } catch {
            self.error = error.localizedDescription
        }
    }
}
