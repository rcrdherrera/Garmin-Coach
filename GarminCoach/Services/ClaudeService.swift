import Foundation

enum ClaudeError: LocalizedError {
    case missingAPIKey
    case apiError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key not set. Go to Settings to add your Anthropic API key."
        case .apiError(let msg):
            return "Claude error: \(msg)"
        case .invalidResponse:
            return "Unexpected response from Claude."
        }
    }
}

class ClaudeService {
    static let shared = ClaudeService()

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private let systemPrompt = """
    You are an expert running coach with deep knowledge of exercise physiology. \
    Analyze the athlete's training data from Apple Health and provide evidence-based, \
    actionable coaching insights.

    The athlete uses a dual-threshold 5-zone model:
    - Z1: Recovery (<147 bpm)
    - Z2: Aerobic base (147–162 bpm, up to LT1)
    - Z3: Tempo (163–173 bpm)
    - Z4: Threshold (174–181 bpm, LT2)
    - Z5: VO2max work (182+ bpm, above 95% HRmax=191)

    Keep responses practical and concise. Focus on what to do next, not just \
    what was done. Highlight any red flags (overtraining, underrecovery, \
    imbalanced training distribution).
    """

    func getCoachingInsight(prompt: String) async throws -> String {
        guard let apiKey = KeychainHelper.loadAPIKey() else {
            throw ClaudeError.missingAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "claude-opus-4-7",
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [["role": "user", "content": prompt]]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        guard http.statusCode == 200 else {
            let errorMsg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["error"] as? [String: Any] }
                .flatMap { $0["message"] as? String }
                ?? "HTTP \(http.statusCode)"
            throw ClaudeError.apiError(errorMsg)
        }

        struct ClaudeResponse: Decodable {
            struct Block: Decodable { let type: String; let text: String }
            let content: [Block]
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw ClaudeError.invalidResponse
        }
        return text
    }
}
