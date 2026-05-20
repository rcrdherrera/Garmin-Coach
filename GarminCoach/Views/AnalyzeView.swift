import SwiftUI

struct AnalyzeView: View {
    @State private var report = ""
    @State private var period = "week"
    @State private var isLoading = false
    @State private var error: String?
    @State private var lastUpdated: Date?

    private let periods: [(label: String, value: String)] = [
        ("This week",  "week"),
        ("Last week",  "last-week"),
        ("This month", "month"),
        ("Last month", "last-month"),
        ("This year",  "year"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                periodPicker

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let updated = lastUpdated {
                            Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                                .font(.caption).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        if isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Analyzing \(periods.first(where: { $0.value == period })?.label.lowercased() ?? period)…")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)

                        } else if let error {
                            errorCard(error)

                        } else if !report.isEmpty {
                            Text(report)
                                .font(.body)
                                .lineSpacing(5)

                        } else {
                            ContentUnavailableView(
                                "No Analysis",
                                systemImage: "chart.bar.xaxis",
                                description: Text("Select a period and tap Analyze.")
                            ).padding(.top, 40)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Analyze")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await analyze() } } label: {
                        if isLoading { ProgressView().scaleEffect(0.8) }
                        else { Label("Analyze", systemImage: "chart.bar.doc.horizontal") }
                    }.disabled(isLoading)
                }
            }
        }
    }

    private var periodPicker: some View {
        Picker("Period", selection: $period) {
            ForEach(periods, id: \.value) { Text($0.label).tag($0.value) }
        }
        .pickerStyle(.segmented)
        .padding()
        .background(Color(.systemGroupedBackground))
        .onChange(of: period) { _, _ in report = ""; error = nil; lastUpdated = nil }
    }

    @ViewBuilder
    private func errorCard(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Error", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red).fontWeight(.semibold)
            Text(msg).foregroundStyle(.secondary).font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func analyze() async {
        isLoading = true; error = nil
        defer { isLoading = false }
        do {
            let resp = try await ServerClient.shared.analyze(period: period)
            report = resp.report
            lastUpdated = .now
        } catch {
            self.error = error.localizedDescription
        }
    }
}
