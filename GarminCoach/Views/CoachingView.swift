import SwiftUI

struct CoachingView: View {
    @State private var brief = ""
    @State private var sessionType = "weekly"
    @State private var isLoading = false
    @State private var error: String?
    @State private var lastUpdated: Date?

    private let sessionTypes: [(label: String, value: String, icon: String)] = [
        ("Weekly Plan",  "weekly",     "calendar.badge.plus"),
        ("Run Session",  "running",    "figure.run"),
        ("Strength",     "strength",   "dumbbell.fill"),
        ("Lower Body",   "lower-body", "figure.strengthtraining.functional"),
        ("Upper Body",   "upper-body", "figure.arms.open"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sessionTypePicker

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if isLoading {
                            LoadingCard(message: "Designing your \(sessionTypes.first(where: { $0.value == sessionType })?.label.lowercased() ?? sessionType)…")

                        } else if let error {
                            ErrorCard(message: error)

                        } else if !brief.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                if let updated = lastUpdated {
                                    Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                Text(brief)
                                    .font(.body)
                                    .lineSpacing(5)
                            }
                            .padding(16)
                            .background(.regularMaterial,
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        } else {
                            ContentUnavailableView(
                                "No Session Yet",
                                systemImage: "figure.run.circle",
                                description: Text("Choose a session type and tap Coach to get your personalized plan based on today's readiness.")
                            ).padding(.top, 40)
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Coach")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await getCoaching() } } label: {
                        if isLoading { ProgressView().scaleEffect(0.8) }
                        else { Label("Coach", systemImage: "wand.and.stars") }
                    }.disabled(isLoading)
                }
            }
        }
    }

    private var sessionTypePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sessionTypes, id: \.value) { st in
                    Button {
                        sessionType = st.value
                        brief = ""; error = nil; lastUpdated = nil
                    } label: {
                        Label(st.label, systemImage: st.icon)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(sessionType == st.value ? Color.accentColor : Color(.secondarySystemFill),
                                        in: Capsule())
                            .foregroundStyle(sessionType == st.value ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func getCoaching() async {
        isLoading = true; error = nil
        defer { isLoading = false }
        do {
            let resp = try await ServerClient.shared.coach(type: sessionType)
            brief = resp.brief
            lastUpdated = .now
        } catch {
            self.error = error.localizedDescription
        }
    }
}
