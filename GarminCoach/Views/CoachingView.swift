import SwiftUI

private enum UploadState {
    case idle
    case uploading
    case done([UploadedWorkout])
    case failed(String)
}

struct CoachingView: View {
    @State private var coachResponse: CoachResponse?
    @State private var sessionType = "weekly"
    @State private var uploadState: UploadState = .idle
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sessionTypePicker

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if isLoading {
                            loadingCard
                        } else if let err = error {
                            errorCard(err)
                        } else if !brief.isEmpty {
                            briefCard
                            uploadSection
                        } else {
                            emptyState
                        }
                    }
                    .padding()
                }
                .background(Color.brutalBackground)
            }
            .background(Color.brutalBackground.ignoresSafeArea())
            .navigationTitle("COACH")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await getCoaching() } } label: {
                        if isLoading {
                            ProgressView().scaleEffect(0.8).tint(.white)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "wand.and.stars")
                                Text("Coach")
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

    // MARK: - Session Type Picker

    private var sessionTypePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(sessionTypes, id: \.value) { st in
                    Button {
                        sessionType = st.value
                        clearResults()
                    } label: {
                        Text(st.label.uppercased())
                            .font(.system(size: 11, weight: .black))
                            .tracking(0.5)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                sessionType == st.value ? Color.brutalRed : Color(white: 0.12),
                                in: RoundedRectangle(cornerRadius: 4)
                            )
                            .foregroundStyle(sessionType == st.value ? .white : Color.white.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(sessionType == st.value ? Color.clear : Color.brutalBorder, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color.black)
        .overlay(alignment: .bottom) { Divider().background(Color.brutalBorder) }
    }

    // MARK: - Loading

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.brutalRed)
            Text("DESIGNING YOUR \(currentLabel.uppercased())")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.4))
                .tracking(1.5)
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
            Text(msg)
                .font(.callout)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brutalRed.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("NO SESSION")
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(Color.white.opacity(0.1))
            Text("Choose a session type and tap Coach.")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }

    // MARK: - Brief Card

    private var briefCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Rectangle().fill(Color.brutalRed).frame(width: 3, height: 14)
                    Text(currentLabel.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Color.brutalRed)
                        .tracking(1.5)
                }
                Spacer()
                if let updated = lastUpdated {
                    Text(updated.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.25))
                }
            }

            Divider().background(Color.brutalBorder)

            Text(brief)
                .font(.system(size: 15, weight: .regular))
                .lineSpacing(6)
                .foregroundStyle(Color.white.opacity(0.9))
        }
        .padding(16)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brutalBorder, lineWidth: 1))
    }

    // MARK: - Upload Section

    @ViewBuilder
    private var uploadSection: some View {
        switch uploadState {
        case .idle:
            Button { Task { await uploadWorkouts() } } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("UPLOAD TO GARMIN")
                        .font(.system(size: 13, weight: .black))
                        .tracking(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(Color.brutalRed, in: RoundedRectangle(cornerRadius: 8))
            }

        case .uploading:
            HStack(spacing: 10) {
                ProgressView().tint(.white)
                Text("UPLOADING TO GARMIN")
                    .font(.system(size: 13, weight: .black))
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(Color.white.opacity(0.6))
            .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.brutalBorder, lineWidth: 1))

        case .done(let workouts):
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("UPLOADED TO GARMIN")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.green)
                        .tracking(1.5)
                }

                Divider().background(Color.brutalBorder)

                ForEach(workouts) { w in
                    HStack(spacing: 10) {
                        Image(systemName: w.error == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(w.error == nil ? .green : .orange)
                            .font(.subheadline)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.name)
                                .font(.system(size: 13, weight: .bold))
                            Text(formattedDate(w.date))
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.4))
                            if let err = w.error {
                                Text(err).font(.caption2).foregroundStyle(.orange)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }

                Text("Sync your Garmin watch via the Connect app to see these workouts.")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.3))
                    .padding(.top, 2)
            }
            .padding(16)
            .background(Color.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.2), lineWidth: 1))

        case .failed(let msg):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("UPLOAD FAILED")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.orange)
                        .tracking(1.5)
                }
                Text(msg)
                    .font(.callout)
                    .foregroundStyle(Color.white.opacity(0.7))

                Button { Task { await uploadWorkouts() } } label: {
                    Text("RETRY")
                        .font(.system(size: 12, weight: .black))
                        .tracking(1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .foregroundStyle(.white)
                        .background(Color.orange, in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(16)
            .background(Color.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.25), lineWidth: 1))
        }
    }

    // MARK: - Helpers

    private var currentLabel: String {
        sessionTypes.first(where: { $0.value == sessionType })?.label ?? sessionType
    }

    private func formattedDate(_ iso: String) -> String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        guard let d = df.date(from: iso) else { return iso }
        return d.formatted(date: .abbreviated, time: .omitted)
    }

    private func clearResults() {
        coachResponse = nil; error = nil; lastUpdated = nil; uploadState = .idle
    }

    // MARK: - Fetch (no upload)

    private func getCoaching() async {
        isLoading = true; error = nil; uploadState = .idle
        defer { isLoading = false }
        do {
            coachResponse = try await ServerClient.shared.coach(type: sessionType, upload: false)
            lastUpdated = .now
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Upload

    private func uploadWorkouts() async {
        uploadState = .uploading
        do {
            let resp = try await ServerClient.shared.coach(type: sessionType, upload: true)
            let workouts = resp.uploadedWorkouts ?? []
            uploadState = .done(workouts)
        } catch {
            uploadState = .failed(error.localizedDescription)
        }
    }
}
