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
                VStack(alignment: .leading, spacing: 12) {
                    if isLoading {
                        LoadingCard(message: "Evaluating last run…")

                    } else if let error {
                        ErrorCard(message: error)

                    } else if !report.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                HStack(spacing: 6) {
                                    Rectangle().fill(Color.brutalRed).frame(width: 3, height: 14)
                                    if let dateStr = activityDate {
                                        Text(dateStr.uppercased())
                                            .font(.system(size: 10, weight: .black))
                                            .foregroundStyle(Color.white.opacity(0.5))
                                            .tracking(1)
                                    }
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

                    } else {
                        VStack(spacing: 10) {
                            Text("NO EVALUATION")
                                .font(.system(size: 28, weight: .black))
                                .foregroundStyle(Color.white.opacity(0.1))
                            Text("Tap Evaluate after a run to get a coaching assessment.")
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.35))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(60)
                    }
                }
                .padding()
            }
            .background(Color.brutalBackground.ignoresSafeArea())
            .navigationTitle("EVALUATE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await evaluate() } } label: {
                        if isLoading {
                            ProgressView().scaleEffect(0.8).tint(.white)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.seal")
                                Text("Evaluate")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundStyle(Color.brutalRed)
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
        .preferredColorScheme(.dark)
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
