import SwiftUI

private enum UploadState {
    case idle
    case uploading
    case done([UploadedWorkout])
    case failed(String)
}

// Free-chat mode uses nil; structured types use the string value
private let freeChatMode = "ask"

struct CoachingView: View {
    @State private var sessionType: String? = nil  // nil = free chat
    @State private var uploadState: UploadState = .idle
    @State private var isLoading = false
    @State private var error: String?
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
    private var isFreeChatMode: Bool { sessionType == nil }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                typePicker

                if isLoading && messages.isEmpty {
                    ScrollView { VStack { loadingCard }.padding() }
                        .background(Color.brutalBackground)
                } else if let err = error, messages.isEmpty {
                    ScrollView { VStack { errorCard(err) }.padding() }
                        .background(Color.brutalBackground)
                } else if hasConversation {
                    conversationArea
                } else if isFreeChatMode {
                    freeChatEmptyState
                } else {
                    ScrollView { VStack { structuredEmptyState }.padding() }
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
                if !isFreeChatMode && !isLoading {
                    ToolbarItem(placement: .primaryAction) {
                        Button { Task { await getCoaching() } } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "wand.and.stars")
                                Text("Coach").font(.system(size: 14, weight: .bold))
                            }
                            .foregroundStyle(Color.brutalRed)
                        }
                    }
                } else if isLoading {
                    ToolbarItem(placement: .primaryAction) {
                        ProgressView().scaleEffect(0.8).tint(.white)
                    }
                }
                if hasConversation {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("New") { clearResults() }
                            .foregroundStyle(Color.brutalRed)
                            .font(.system(size: 14, weight: .bold))
                    }
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

    // MARK: - Type picker

    private var typePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Free chat chip
                Button {
                    sessionType = nil
                    clearResults()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.fill").font(.caption)
                        Text("CHAT")
                            .font(.system(size: 11, weight: .black))
                            .tracking(0.5)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        sessionType == nil ? Color.brutalRed : Color(white: 0.12),
                        in: RoundedRectangle(cornerRadius: 4)
                    )
                    .foregroundStyle(sessionType == nil ? .white : Color.white.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(sessionType == nil ? Color.clear : Color.brutalBorder, lineWidth: 1)
                    )
                }

                // Structured session types
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

    // MARK: - Free chat empty state (suggestions)

    private var freeChatEmptyState: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 30)
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(white: 0.1))
                            .frame(width: 72, height: 72)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.brutalBorder, lineWidth: 1))
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(Color.brutalRed)
                    }
                    Text("ASK YOUR COACH")
                        .font(.system(size: 22, weight: .black)).tracking(1)
                    Text("Evidence-based answers about\nyour training, recovery, and goals.")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                }
                VStack(spacing: 6) {
                    ForEach(coachSuggestions, id: \.self) { suggestion in
                        Button {
                            Task { await sendFreeChat(suggestion) }
                        } label: {
                            HStack {
                                Text(suggestion).font(.subheadline)
                                    .foregroundStyle(Color.white.opacity(0.8))
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.caption)
                                    .foregroundStyle(Color.brutalRed)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.brutalBorder, lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal)
                Spacer(minLength: 100)
            }
            .padding()
        }
        .background(Color.brutalBackground)
        .safeAreaInset(edge: .bottom) { freeChatInputBar }
    }

    // MARK: - Free chat input bar (standalone, for empty state)

    @State private var freeChatInput = ""
    @FocusState private var freeChatFocused: Bool

    private var freeChatInputBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.brutalBorder)
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask your coach…", text: $freeChatInput, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color(white: 0.1), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.brutalBorder, lineWidth: 1))
                    .foregroundStyle(.white).focused($freeChatFocused)
                    .disabled(isLoading)
                Button { Task { await sendFreeChat(nil) } } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(
                            !freeChatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.brutalRed : Color.white.opacity(0.2)
                        )
                }
                .disabled(freeChatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
        }
        .background(Color.black)
    }

    // MARK: - Conversation area (structured + free chat after first message)

    private var conversationArea: some View {
        VStack(spacing: 0) {
            // Upload section for structured sessions
            if !isFreeChatMode {
                uploadBar
            }
            ConversationThreadView(
                kind: isFreeChatMode ? "ask" : "coach",
                conversationId: $conversationId,
                messages: $messages
            )
        }
        .background(Color.brutalBackground)
    }

    @ViewBuilder
    private var uploadBar: some View {
        switch uploadState {
        case .idle:
            Button { Task { await uploadWorkouts() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("UPLOAD TO GARMIN").font(.system(size: 12, weight: .black)).tracking(1)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 12).foregroundStyle(.white)
                .background(Color.brutalRed)
            }

        case .uploading:
            HStack(spacing: 8) {
                ProgressView().tint(.white).scaleEffect(0.8)
                Text("UPLOADING TO GARMIN").font(.system(size: 12, weight: .black)).tracking(1)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .foregroundStyle(Color.white.opacity(0.6)).background(Color(white: 0.12))
            .overlay(alignment: .bottom) { Divider().background(Color.brutalBorder) }

        case .done(let workouts):
            ScrollView(.horizontal, showsIndicators: false) {
                uploadDoneCard(workouts).padding(.horizontal).padding(.vertical, 8)
            }
            .background(Color.black)
            .overlay(alignment: .bottom) { Divider().background(Color.brutalBorder) }

        case .failed(let msg):
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(msg).font(.caption).foregroundStyle(Color.white.opacity(0.7))
                Spacer()
                Button { Task { await uploadWorkouts() } } label: {
                    Text("RETRY").font(.system(size: 11, weight: .black))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .foregroundStyle(.white).background(Color.orange, in: RoundedRectangle(cornerRadius: 5))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.orange.opacity(0.07))
            .overlay(alignment: .bottom) { Divider().background(Color.orange.opacity(0.3)) }
        }
    }

    private func uploadDoneCard(_ workouts: [UploadedWorkout]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                Text("UPLOADED TO GARMIN").font(.system(size: 9, weight: .black)).foregroundStyle(.green).tracking(1.5)
            }
            ForEach(workouts) { w in
                HStack(spacing: 8) {
                    Image(systemName: w.error == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(w.error == nil ? .green : .orange).font(.caption2)
                    Text(w.name).font(.caption2).foregroundStyle(Color.white.opacity(0.7))
                    Spacer()
                    Text(formattedDate(w.date)).font(.caption2).foregroundStyle(Color.white.opacity(0.3))
                }
            }
            Text("Sync your watch via the Connect app.")
                .font(.caption2).foregroundStyle(Color.white.opacity(0.25))
        }
        .padding(12)
        .background(Color.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Loading / Error / Empty

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView().progressViewStyle(.circular).tint(Color.brutalRed)
            Text("DESIGNING YOUR \(currentLabel.uppercased())")
                .font(.system(size: 10, weight: .bold)).foregroundStyle(Color.white.opacity(0.4)).tracking(1.5)
        }
        .frame(maxWidth: .infinity).padding(40)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brutalBorder, lineWidth: 1))
    }

    private func errorCard(_ msg: String) -> some View {
        HStack(spacing: 10) {
            Rectangle().fill(Color.brutalRed).frame(width: 3)
            Text(msg).font(.callout).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brutalRed.opacity(0.4), lineWidth: 1))
    }

    private var structuredEmptyState: some View {
        VStack(spacing: 12) {
            Text("NO SESSION")
                .font(.system(size: 32, weight: .black)).foregroundStyle(Color.white.opacity(0.1))
            Text("Choose a session type and tap Coach.")
                .font(.subheadline).foregroundStyle(Color.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity).padding(60)
    }

    // MARK: - Helpers

    private var currentLabel: String {
        sessionTypes.first(where: { $0.value == sessionType })?.label ?? sessionType ?? ""
    }

    private static let _isoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func formattedDate(_ iso: String) -> String {
        guard let d = Self._isoDateFormatter.date(from: iso) else { return iso }
        return d.formatted(date: .abbreviated, time: .omitted)
    }

    private func clearResults() {
        error = nil; lastUpdated = nil; uploadState = .idle
        conversationId = nil; messages = []
        freeChatInput = ""
    }

    @State private var lastUpdated: Date?

    // MARK: - Generate coaching brief (structured mode)

    private func getCoaching() async {
        guard let type = sessionType else { return }
        isLoading = true; error = nil; uploadState = .idle
        conversationId = nil; messages = []
        defer { isLoading = false }
        do {
            let resp = try await ServerClient.shared.coach(type: type, upload: false)
            conversationId = resp.conversationId
            messages = [ChatMessage(role: .assistant, text: resp.brief)]
            lastUpdated = .now
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Upload workouts (reuse existing conversation)

    private func uploadWorkouts() async {
        guard let type = sessionType else { return }
        uploadState = .uploading
        do {
            let resp = try await ServerClient.shared.coach(
                type: type,
                upload: true,
                conversationId: conversationId   // reuse — no new history entry created
            )
            uploadState = .done(resp.uploadedWorkouts ?? [])
            if !messages.isEmpty {
                messages[0] = ChatMessage(role: .assistant, text: resp.brief)
            }
        } catch {
            uploadState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Free chat send

    private func sendFreeChat(_ overrideText: String?) async {
        let text = overrideText ?? freeChatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        freeChatInput = ""
        error = nil
        withAnimation { messages.append(ChatMessage(role: .user, text: text)) }
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await ServerClient.shared.sendChat(
                conversationId: conversationId,
                message: text,
                kind: "ask"
            )
            conversationId = resp.conversationId
            withAnimation { messages.append(ChatMessage(role: .assistant, text: resp.message.content)) }
        } catch {
            self.error = error.localizedDescription
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
            // Determine mode from kind
            if detail.kind == "ask" { sessionType = nil } // free chat
            messages = detail.messages.map {
                ChatMessage(role: $0.isUser ? .user : .assistant, text: $0.content)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
