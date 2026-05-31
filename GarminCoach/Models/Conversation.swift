import Foundation

// MARK: - Conversation models

struct ConversationSummary: Decodable, Identifiable {
    let id: Int
    let kind: String
    let title: String?
    let createdAt: String
    let updatedAt: String
    let preview: String?

    enum CodingKeys: String, CodingKey {
        case id, kind, title, preview
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var displayTitle: String { title?.isEmpty == false ? title! : "Untitled" }
}

struct ConversationMessage: Decodable, Identifiable {
    let id: Int
    let role: String   // "user" | "assistant"
    let content: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, role, content
        case createdAt = "created_at"
    }

    var isUser: Bool { role == "user" }
}

struct ConversationDetail: Decodable {
    let id: Int
    let kind: String
    let title: String?
    let createdAt: String
    let updatedAt: String
    let messages: [ConversationMessage]

    enum CodingKeys: String, CodingKey {
        case id, kind, title, messages
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ConversationListResponse: Decodable {
    let conversations: [ConversationSummary]
}

struct ChatTurnResponse: Decodable {
    let conversationId: Int
    let title: String
    let message: ConversationMessage

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case title, message
    }
}
