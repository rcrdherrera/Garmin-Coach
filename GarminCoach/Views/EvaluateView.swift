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
                    if let updated = lastUpdated {
                        Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                            .font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Evaluating last run…").foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)

                    } else if let error {
                        errorCard(error)

                    } else if !report.isEmpty {
                        if let dateStr = activityDate {
                            Text(dateStr)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Text(report)
                            .font(.body)
                            .lineSpacing(5)
                            .fontDesign(.monospaced)

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
