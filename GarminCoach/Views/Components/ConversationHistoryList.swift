import SwiftUI

// MARK: - Shared conversation history sheet (used by Coach, Analyze, and Ask tabs)

struct ConversationHistoryList: View {
    let kind: String
    let onSelect: (ConversationSummary) -> Void
    let onNew: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var conversations: [ConversationSummary] = []
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading && conversations.isEmpty {
                    loadingView
                } else if let err = errorText, conversations.isEmpty {
                    errorView(err)
                } else if conversations.isEmpty {
                    emptyView
                } else {
                    conversationList
                }
            }
            .navigationTitle("HISTORY")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.brutalRed)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onNew()
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("New")
                        }
                        .foregroundStyle(Color.brutalRed)
                        .font(.system(size: 14, weight: .bold))
                    }
                }
            }
            .task { await loadConversations() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - List

    private var conversationList: some View {
        List {
            ForEach(conversations) { conv in
                Button {
                    onSelect(conv)
                    dismiss()
                } label: {
                    conversationRow(conv)
                }
                .listRowBackground(Color(white: 0.07))
                .listRowSeparatorTint(Color.white.opacity(0.08))
            }
            .onDelete { offsets in
                let toDelete = offsets.map { conversations[$0].id }
                conversations.remove(atOffsets: offsets)
                Task {
                    for id in toDelete {
                        try? await ServerClient.shared.deleteConversation(id: id)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .refreshable { await loadConversations() }
    }

    @ViewBuilder
    private func conversationRow(_ conv: ConversationSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(conv.displayTitle)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            if let preview = conv.preview, !preview.isEmpty {
                Text(preview)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.45))
                    .lineLimit(2)
            }
            Text(relativeDate(conv.updatedAt))
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.25))
        }
        .padding(.vertical, 4)
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView().tint(Color.brutalRed)
            Text("LOADING HISTORY")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.35))
                .tracking(1.5)
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(Color.brutalRed)
            Text(msg)
                .font(.callout)
                .foregroundStyle(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Text("NO HISTORY")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(Color.white.opacity(0.1))
            Text("Your conversations will appear here.")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.3))
        }
    }

    // MARK: - Data

    private func loadConversations() async {
        isLoading = true
        defer { isLoading = false }
        do {
            conversations = try await ServerClient.shared.getConversations(kind: kind)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func relativeDate(_ iso: String) -> String {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let df2 = ISO8601DateFormatter()
        df2.formatOptions = [.withInternetDateTime]
        guard let date = df.date(from: iso + "Z") ?? df2.date(from: iso + "Z") else { return iso }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}
