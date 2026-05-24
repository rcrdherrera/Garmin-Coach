import SwiftUI

struct CoachingView: View {
    @State private var coachResponse: CoachResponse?
    @State private var sessionType = "weekly"
    @State private var uploadToGarmin = false
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

    private var brief: String { coachResponse?.brief ?? "" }
    private var uploaded: [UploadedWorkout] { coachResponse?.uploadedWorkouts ?? [] }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sessionTypePicker
                uploadToggle

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if isLoading {
                            LoadingCard(message: uploadToGarmin
                                ? "Building and uploading your \(currentLabel) to Garmin…"
                                : "Designing your \(currentLabel)…")

                        } else if let err = error {
                            ErrorCard(message: err)

                        } else if !brief.isEmpty {
                            briefCard
                            if !uploaded.isEmpty {
                                uploadedCard
                            }

                        } else {
                            ContentUnavailableView(
                                "No Session Yet",
                                systemImage: "figure.run.circle",
                                description: Text("Choose a session type and tap Coach.")
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
                        if isLoading {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Label(
                                uploadToGarmin ? "Coach & Upload" : "Coach",
                                systemImage: uploadToGarmin ? "arrow.up.circle.fill" : "wand.and.stars"
                            )
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
    }

    // MARK: - Session Type Picker

    private var sessionTypePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sessionTypes, id: \.value) { st in
                    Button {
                        sessionType = st.value
                        clearResults()
                    } label: {
                        Label(st.label, systemImage: st.icon)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                sessionType == st.value ? Color.accentColor : Color(.secondarySystemFill),
                                in: Capsule()
                            )
                            .foregroundStyle(sessionType == st.value ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Upload Toggle

    private var uploadToggle: some View {
        HStack {
            Label("Upload to Garmin", systemImage: "arrow.up.circle")
                .font(.subheadline)
                .foregroundStyle(uploadToGarmin ? .primary : .secondary)
            Spacer()
            Toggle("", isOn: $uploadToGarmin)
                .labelsHidden()
                .onChange(of: uploadToGarmin) { _, _ in clearResults() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .top) { Divider() }
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Brief Card

    private var briefCard: some View {
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Uploaded Card

    private var uploadedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Uploaded to Garmin", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)

            ForEach(uploaded) { w in
                HStack(spacing: 12) {
                    Image(systemName: w.error == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(w.error == nil ? .green : .orange)
                        .font(.subheadline)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(w.name)
                            .font(.subheadline.weight(.medium))
                        Text(formattedDate(w.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let err = w.error {
                            Text(err)
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)

                if w.id != uploaded.last?.id {
                    Divider().padding(.leading, 28)
                }
            }

            Text("Sync your watch via Garmin Connect to see these workouts.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(16)
        .background(Color.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Helpers

    private var currentLabel: String {
        sessionTypes.first(where: { $0.value == sessionType })?.label.lowercased() ?? sessionType
    }

    private func formattedDate(_ iso: String) -> String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        guard let d = df.date(from: iso) else { return iso }
        return d.formatted(date: .abbreviated, time: .omitted)
    }

    private func clearResults() {
        coachResponse = nil; error = nil; lastUpdated = nil
    }

    // MARK: - Fetch

    private func getCoaching() async {
        isLoading = true; error = nil
        defer { isLoading = false }
        do {
            coachResponse = try await ServerClient.shared.coach(type: sessionType, upload: uploadToGarmin)
            lastUpdated = .now
        } catch {
            self.error = error.localizedDescription
        }
    }
}
