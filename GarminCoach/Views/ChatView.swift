import SwiftUI

// Shared suggestion prompts used by CoachingView free-chat empty state.
let coachSuggestions: [String] = [
    "How's my training load this week?",
    "Am I ready for a hard session today?",
    "What pace should I target for easy runs?",
    "How's my HRV trend lately?",
]

// MARK: - Shared message type (used by Coach, Analyze, and Ask tabs)

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    enum Role: String, Codable { case user, assistant }
    let role: Role
    let text: String
    init(role: Role, text: String) { self.id = UUID(); self.role = role; self.text = text }
}

// MARK: - Message Bubble (shared with CoachingView and AnalyzeView)

struct MessageBubble: View {
    let message: ChatMessage
    var onRemember: ((String) -> Void)? = nil
    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: 60) }

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
                if !isUser, let onRemember {
                    Button("Remember", systemImage: "brain") {
                        onRemember(message.text)
                    }
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
    @State private var rememberedToast = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                messageList
                inputBar
            }

            if rememberedToast {
                VStack {
                    Spacer()
                    Text("Saved to context")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(white: 0.15), in: Capsule())
                        .overlay(Capsule().stroke(Color.brutalBorder, lineWidth: 1))
                        .foregroundStyle(.white)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 80)
                }
            }
        }
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(messages) { msg in
                        MessageBubble(message: msg, onRemember: { text in
                            Task { await rememberNote(text) }
                        }).id(msg.id)
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

    private func rememberNote(_ text: String) async {
        try? await ServerClient.shared.remember(note: text)
        withAnimation { rememberedToast = true }
        try? await Task.sleep(for: .seconds(2))
        withAnimation { rememberedToast = false }
    }
}
