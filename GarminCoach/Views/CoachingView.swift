import SwiftUI

struct CoachingView: View {
    @State private var insight = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var lastUpdated: Date?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let updated = lastUpdated {
                        Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Analyzing your training…")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)

                    } else if let error {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Error", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .fontWeight(.semibold)
                            Text(error)
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

                    } else if !insight.isEmpty {
                        Text(insight)
                            .font(.body)
                            .lineSpacing(5)

                    } else {
                        ContentUnavailableView(
                            "No Insight Yet",
                            systemImage: "figure.run.circle",
                            description: Text("Tap Analyze to get your personalized coaching insight based on your recent Apple Health data.")
                        )
                        .padding(.top, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("Coach")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await analyze() }
                    } label: {
                        if isLoading {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Label("Analyze", systemImage: "wand.and.stars")
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
        .task {
            try? await HealthKitManager.shared.requestPermissions()
        }
    }

    private func analyze() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            async let runs    = HealthKitManager.shared.recentRuns(limit: 20)
            async let metrics = HealthKitManager.shared.athleteMetrics()

            let prompt = CoachingContextBuilder.build(
                runs: try await runs,
                metrics: try await metrics
            )

            insight = try await ClaudeService.shared.getCoachingInsight(prompt: prompt)
            lastUpdated = .now
        } catch {
            self.error = error.localizedDescription
        }
    }
}
