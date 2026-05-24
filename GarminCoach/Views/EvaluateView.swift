import SwiftUI

struct EvaluateView: View {
    @State private var report = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var lastUpdated: Date?
    @State private var activityDate: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        LoadingCard(message: "Evaluating last run…")

                    } else if let error {
                        ErrorCard(message: error)

                    } else if !report.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                if let dateStr = activityDate {
                                    Label(dateStr, systemImage: "calendar")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
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
                                .fontDesign(.monospaced)
                        }
                        .padding(16)
                        .background(.regularMaterial,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    } else {
                        ContentUnavailableView(
                            "No Evaluation",
                            systemImage: "checkmark.seal",
                            description: Text("Tap Evaluate after completing a run to get a coaching assessment and plan adjustments.")
                        ).padding(.top, 40)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Evaluate")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await evaluate() } } label: {
                        if isLoading { ProgressView().scaleEffect(0.8) }
                        else { Label("Evaluate", systemImage: "checkmark.seal") }
                    }.disabled(isLoading)
                }
            }
        }
    }

    private func evaluate() async {
        isLoading = true; error = nil
        defer { isLoading = false }
        do {
            let resp = try await ServerClient.shared.evaluate()
            report = resp.report
            activityDate = resp.date
            lastUpdated = .now
        } catch {
            self.error = error.localizedDescription
        }
    }
}
