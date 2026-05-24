import SwiftUI

// MARK: - Model

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    enum Role: String, Codable { case user, assistant }
    let role: Role
    let text: String

    init(role: Role, text: String) {
        self.id = UUID()
        self.role = role
        self.text = text
    }
}

// MARK: - ChatView

struct ChatView: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorText: String?
    @FocusState private var inputFocused: Bool

    private let storageKey = "garmincoach_chat_history"

    private let suggestions = [
        "How's my training load this week?",
        "Am I ready for a hard session today?",
        "What pace should I target for easy runs?",
        "How's my HRV trend lately?",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if messages.isEmpty && !isLoading {
                    emptyState
                        .transition(.opacity)
                } else {
                    messageList
                }
            }
            .navigationTitle("Ask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !messages.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Clear") {
                            withAnimation { messages = []; errorText = nil }
                            clearStorage()
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                inputBar
            }
            .onAppear { loadMessages() }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 40)

                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.blue.opacity(0.1))
                            .frame(width: 88, height: 88)
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(.blue)
                    }

                    Text("Ask Your Coach")
                        .font(.title2.weight(.bold))
                    Text("Get evidence-based answers about\nyour training, recovery, and goals.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            inputText = suggestion
                            inputFocused = true
                        } label: {
                            HStack {
                                Text(suggestion)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                            .background(.regularMaterial,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }

                    if isLoading {
                        HStack {
                            TypingIndicator()
                            Spacer()
                        }
                        .padding(.horizontal)
                        .id("typing")
                    }

                    if let err = errorText {
                        HStack {
                            Label(err, systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.red.opacity(0.08),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: isLoading) { _, loading in
                if loading {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask your coach…", text: $inputText, axis: .vertical)
                    .lineLimit(1...6)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemFill),
                                in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .focused($inputFocused)
                    .disabled(isLoading)

                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(canSend ? .blue : Color(.tertiaryLabel))
                        .animation(.easeInOut(duration: 0.15), value: canSend)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(.regularMaterial)
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
        let userMsg = ChatMessage(role: .user, text: text)
        withAnimation { messages.append(userMsg) }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await ServerClient.shared.chat(message: text)
            let assistantMsg = ChatMessage(role: .assistant, text: response)
            withAnimation { messages.append(assistantMsg) }
            saveMessages()
        } catch {
            withAnimation { errorText = error.localizedDescription }
        }
    }

    // MARK: - Persistence

    private func saveMessages() {
        guard let data = try? JSONEncoder().encode(messages) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadMessages() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([ChatMessage].self, from: data)
        else { return }
        messages = saved
    }

    private func clearStorage() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: 60) }

            Text(message.text)
                .font(.body)
                .lineSpacing(3)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isUser ? Color.blue : Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .foregroundStyle(isUser ? .white : .primary)
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

// MARK: - Typing Indicator

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
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }

    private func dot(delay: Double) -> some View {
        Circle()
            .fill(Color.secondary.opacity(0.6))
            .frame(width: 8, height: 8)
            .offset(y: animating ? -4 : 4)
            .animation(
                .easeInOut(duration: 0.4)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: animating
            )
    }
}
