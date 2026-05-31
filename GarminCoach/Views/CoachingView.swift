import SwiftUI

private enum UploadState {
    case idle
    case uploading
    case done([UploadedWorkout])
    case failed(String)
}

struct CoachingView: View {
    @State private var sessionType = "weekly"
    @State private var uploadState: UploadState = .idle
    @State private var isLoading = false
    @State private var error: String?
    @State private var lastUpdated: Date?
    @State private var showHistory = false

    // Conversation state
    @State private var conversationId: Int?
    @State private var messages: [ChatMessage] = []

    private let sessionTypes: [(label: String, value: String, icon: String)] = [
        ("Weekly Plan",  "weekly",     "calendar.badge.plus"),
        ("Run Session",  "running",    "figure.run"),
        ("Strength",     "strength",   "dumbbell.fill"),
        ("Lower Body",   "lower-body", "figure.strengthtraining.functional"),
        ("Upper Body",   "upper-body", "figure.arms.open"),
    ]

    private var hasConversation: Bool { !messages.isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sessionTypePicker

                if isLoading && messages.isEmpty {
                    ScrollView {
                        VStack { loadingCard }.padding()
                    }
                    .background(Color.brutalBackground)
                } else if let err = error, messages.isEmpty {
                    ScrollView {
                        VStack { errorCard(err) }.padding()
                    }
                    .background(Color.brutalBackground)
                } else if hasConversation {
                    conversationArea
                } else {
                    ScrollView {
                        VStack { emptyState }.padding()
                    }
                    .background(Color.brutalBackground)
                }
            }
            .background(Color.brutalBackground.ignoresSafeArea())
            .navigationTitle("COACH")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showHistory = true } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
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
            .sheet(isPresented: $showHistory) {
                ConversationHistoryList(
                    kind: "coach",
                    onSelect: { conv in Task { await loadConversation(id: conv.id) } },
                    onNew: { clearResults() }
                )
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

    // MARK: - Conversation Area (active coach thread)

    private var conversationArea: some View {
        VStack(spacing: 0) {
            // Upload section sits above the conversation as a sticky card
            if case .idle = uploadState {
                uploadIdleBar
            } else if case .uploading = uploadState {
                uploadUploadingBar
            } else if case .done(let workouts) = uploadState {
                ScrollView(.horizontal, showsIndicators: false) {
                    uploadDoneCard(workouts)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
                .background(Color.black)
                .overlay(alignment: .bottom) { Divider().background(Color.brutalBorder) }
            } else if case .failed(let msg) = uploadState {
                uploadFailedBar(msg)
            }

            // Conversation thread (messages + input bar)
            ConversationThreadView(
                kind: "coach",
                conversationId: $conversationId,
                messages: $messages
            )
        }
        .background(Color.brutalBackground)
    }

    // MARK: - Upload UI (compact bar/card variants)

    private var uploadIdleBar: some View {
        Button { Task { await uploadWorkouts() } } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.circle.fill")
                Text("UPLOAD TO GARMIN")
                    .font(.system(size: 12, weight: .black))
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(.white)
            .background(Color.brutalRed)
        }
    }

    private var uploadUploadingBar: some View {
        HStack(spacing: 8) {
            ProgressView().tint(.white).scaleEffect(0.8)
            Text("UPLOADING TO GARMIN")
                .font(.system(size: 12, weight: .black))
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .foregroundStyle(Color.white.opacity(0.6))
        .background(Color(white: 0.12))
        .overlay(alignment: .bottom) { Divider().background(Color.brutalBorder) }
    }

    private func uploadDoneCard(_ workouts: [UploadedWorkout]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                Text("UPLOADED TO GARMIN")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.green)
                    .tracking(1.5)
            }
            ForEach(workouts) { w in
                HStack(spacing: 8) {
                    Image(systemName: w.error == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(w.error == nil ? .green : .orange)
                        .font(.caption2)
                    Text(w.name).font(.caption2).foregroundStyle(Color.white.opacity(0.7))
                    Spacer()
                    Text(formattedDate(w.date)).font(.caption2).foregroundStyle(Color.white.opacity(0.3))
                }
            }
            Text("Sync your watch via the Connect app.")
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.25))
        }
        .padding(12)
        .background(Color.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.2), lineWidth: 1))
    }

    private func uploadFailedBar(_ msg: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(msg).font(.caption).foregroundStyle(Color.white.opacity(0.7))
            Spacer()
            Button { Task { await uploadWorkouts() } } label: {
                Text("RETRY")
                    .font(.system(size: 11, weight: .black))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(.white)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 5))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.07))
        .overlay(alignment: .bottom) { Divider().background(Color.orange.opacity(0.3)) }
    }

    // MARK: - Loading / Error / Empty

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
        error = nil
        lastUpdated = nil
        uploadState = .idle
        conversationId = nil
        messages = []
    }

    // MARK: - Fetch coaching brief

    private func getCoaching() async {
        isLoading = true; error = nil; uploadState = .idle
        conversationId = nil; messages = []
        defer { isLoading = false }
        do {
            let resp = try await ServerClient.shared.coach(type: sessionType, upload: false)
            conversationId = resp.conversationId
            messages = [ChatMessage(role: .assistant, text: resp.brief)]
            lastUpdated = .now
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Upload workouts

    private func uploadWorkouts() async {
        uploadState = .uploading
        do {
            let resp = try await ServerClient.shared.coach(type: sessionType, upload: true)
            uploadState = .done(resp.uploadedWorkouts ?? [])
            // Update the first message with the new brief (which references uploaded workouts)
            if !messages.isEmpty {
                messages[0] = ChatMessage(role: .assistant, text: resp.brief)
            }
            // Use the conversation from the upload response if we don't have one yet
            if conversationId == nil {
                conversationId = resp.conversationId
            }
        } catch {
            uploadState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Load historical conversation

    private func loadConversation(id: Int) async {
        clearResults()
        isLoading = true
        defer { isLoading = false }
        do {
            let detail = try await ServerClient.shared.getConversation(id: id)
            conversationId = detail.id
            messages = detail.messages.map {
                ChatMessage(role: $0.isUser ? .user : .assistant, text: $0.content)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
