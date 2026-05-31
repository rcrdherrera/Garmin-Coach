import SwiftUI

// MARK: - Shared message type (used by Coach, Analyze, and Ask tabs)

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    enum Role: String, Codable { case user, assistant }
    let role: Role
    let text: String
    init(role: Role, text: String) { self.id = UUID(); self.role = role; self.text = text }
}

// MARK: - Ask (Chat) tab

struct ChatView: View {
    @State private var currentConversationId: Int?
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var showHistory = false
    @FocusState private var inputFocused: Bool

    private let suggestions = [
        "How's my training load this week?",
        "Am I ready for a hard session today?",
        "What pace should I target for easy runs?",
        "How's my HRV trend lately?",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brutalBackground.ignoresSafeArea()

                if messages.isEmpty && !isLoading {
                    emptyState.transition(.opacity)
                } else {
                    messageList
                }
            }
            .navigationTitle("ASK")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                if !messages.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("New") {
                            withAnimation {
                                messages = []
                                errorText = nil
                                currentConversationId = nil
                            }
                        }
                        .foregroundStyle(Color.brutalRed)
                        .font(.system(size: 14, weight: .bold))
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { inputBar }
            .onTapGesture { inputFocused = false }
            .sheet(isPresented: $showHistory) {
                ConversationHistoryList(
                    kind: "ask",
                    onSelect: { conv in Task { await loadConversation(id: conv.id) } },
                    onNew: {
                        withAnimation {
                            messages = []
                            errorText = nil
                            currentConversationId = nil
                        }
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 40)

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
                        .font(.system(size: 22, weight: .black))
                        .tracking(1)
                    Text("Evidence-based answers about\nyour training, recovery, and goals.")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 6) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            inputText = suggestion
                            inputFocused = true
                        } label: {
                            HStack {
                                Text(suggestion)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.white.opacity(0.8))
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(Color.brutalRed)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
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
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(messages) { msg in
                        MessageBubble(message: msg).id(msg.id)
                    }

                    if isLoading {
                        HStack { TypingIndicator(); Spacer() }
                            .padding(.horizontal)
                            .id("typing")
                    }

                    if let err = errorText {
                        HStack {
                            HStack(spacing: 8) {
                                Rectangle().fill(Color.brutalRed).frame(width: 2)
                                Text(err)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.white.opacity(0.8))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(white: 0.1), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.brutalRed.opacity(0.3), lineWidth: 1))
                            Spacer()
                        }
                        .padding(.horizontal)
                        .id("error")
                    }

                    Color.clear.frame(height: 4).id("bottom")
                }
                .padding(.top, 12)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: isLoading) { _, loading in
                if loading {
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("typing", anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.brutalBorder)
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask your coach…", text: $inputText, axis: .vertical)
                    .lineLimit(1...6)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(white: 0.1), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.brutalBorder, lineWidth: 1))
                    .foregroundStyle(.white)
                    .focused($inputFocused)
                    .disabled(isLoading)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { inputFocused = false }.foregroundStyle(Color.brutalRed)
                        }
                    }

                Button { Task { await send() } } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(canSend ? Color.brutalRed : Color.white.opacity(0.2))
                        .animation(.easeInOut(duration: 0.15), value: canSend)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(Color.black)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    // MARK: - Send

    private func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        errorText = nil
        withAnimation { messages.append(ChatMessage(role: .user, text: text)) }
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await ServerClient.shared.sendChat(
                conversationId: currentConversationId,
                message: text,
                kind: "ask"
            )
            currentConversationId = resp.conversationId
            withAnimation { messages.append(ChatMessage(role: .assistant, text: resp.message.content)) }
        } catch {
            withAnimation { errorText = error.localizedDescription }
        }
    }

    // MARK: - Load historical conversation

    private func loadConversation(id: Int) async {
        isLoading = true
        defer { isLoading = false }
        errorText = nil
        do {
            let detail = try await ServerClient.shared.getConversation(id: id)
            currentConversationId = detail.id
            messages = detail.messages.map {
                ChatMessage(role: $0.isUser ? .user : .assistant, text: $0.content)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - Message Bubble (shared with CoachingView and AnalyzeView)

struct MessageBubble: View {
    let message: ChatMessage
    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: 60) }

            // Render markdown in assistant messages so formatting is human-readable
            Group {
                if isUser {
                    Text(message.text)
                        .font(.body)
                } else {
                    Text(LocalizedStringKey(message.text))
                        .font(.body)
                }
            }
            .lineSpacing(4)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isUser ? Color.brutalRed : Color(white: 0.12),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isUser ? Color.clear : Color.brutalBorder, lineWidth: 1)
            )
            .foregroundStyle(.white)
            .contextMenu {
                Button("Copy", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = message.text
                }
            }

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }
}

// MARK: - Typing Indicator (shared)

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            dot(delay: 0.00)
            dot(delay: 0.15)
            dot(delay: 0.30)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }

    private func dot(delay: Double) -> some View {
        Circle()
            .fill(Color.white.opacity(0.5))
            .frame(width: 8, height: 8)
            .offset(y: animating ? -4 : 4)
            .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(delay), value: animating)
    }
}

// MARK: - Shared message list + input bar view (used by Coach and Analyze tabs)

struct ConversationThreadView: View {
    let kind: String
    @Binding var conversationId: Int?
    @Binding var messages: [ChatMessage]

    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorText: String?
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            messageList
            inputBar
        }
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(messages) { msg in
                        MessageBubble(message: msg).id(msg.id)
                    }

                    if isLoading {
                        HStack { TypingIndicator(); Spacer() }
                            .padding(.horizontal)
                            .id("typing")
                    }

                    if let err = errorText {
                        HStack {
                            HStack(spacing: 8) {
                                Rectangle().fill(Color.brutalRed).frame(width: 2)
                                Text(err)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.white.opacity(0.8))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(white: 0.1), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.brutalRed.opacity(0.3), lineWidth: 1))
                            Spacer()
                        }
                        .padding(.horizontal)
                    }

                    Color.clear.frame(height: 4).id("bottom")
                }
                .padding(.top, 8)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: isLoading) { _, loading in
                if loading {
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("typing", anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.brutalBorder)
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask a follow-up…", text: $inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(white: 0.1), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.brutalBorder, lineWidth: 1))
                    .foregroundStyle(.white)
                    .focused($inputFocused)
                    .disabled(isLoading)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { inputFocused = false }.foregroundStyle(Color.brutalRed)
                        }
                    }

                Button { Task { await send() } } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(canSend ? Color.brutalRed : Color.white.opacity(0.2))
                        .animation(.easeInOut(duration: 0.15), value: canSend)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(Color.black)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    private func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        errorText = nil
        withAnimation { messages.append(ChatMessage(role: .user, text: text)) }
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await ServerClient.shared.sendChat(
                conversationId: conversationId,
                message: text,
                kind: kind
            )
            conversationId = resp.conversationId
            withAnimation { messages.append(ChatMessage(role: .assistant, text: resp.message.content)) }
        } catch {
            withAnimation { errorText = error.localizedDescription }
        }
    }
}
