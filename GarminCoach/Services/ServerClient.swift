import Foundation

// MARK: - Response types

struct ServerStatus: Decodable {
    struct BodyBattery: Decodable {
        let current: Int?
        let high: Int?
        let low: Int?
    }
    struct HRVData: Decodable {
        let lastNight: Int?
        let weeklyAvg: Int?
        let status: String?
        let baselineLow: Int?
        let baselineHigh: Int?
        enum CodingKeys: String, CodingKey {
            case lastNight = "last_night", weeklyAvg = "weekly_avg"
            case status, baselineLow = "baseline_low", baselineHigh = "baseline_high"
        }
    }
    struct Readiness: Decodable {
        let score: Int?
        let level: String?
        let feedback: String?
    }
    struct Sleep: Decodable {
        let score: Int?
        let durationH: Double?
        let deepH: Double?
        let remH: Double?
        enum CodingKeys: String, CodingKey {
            case score, durationH = "duration_h", deepH = "deep_h", remH = "rem_h"
        }
    }

    let date: String
    let bodyBattery: BodyBattery?
    let hrv: HRVData?
    let readiness: Readiness?
    let trainingStatus: String?
    let sleep: Sleep?
    let rhr: Int?
    let stress: Int?

    enum CodingKeys: String, CodingKey {
        case date, bodyBattery = "body_battery", hrv, readiness
        case trainingStatus = "training_status", sleep, rhr, stress
    }
}

struct AnalyzeResponse: Decodable {
    let period: String
    let report: String
}

struct CoachResponse: Decodable {
    let date: String
    let type: String
    let brief: String
}

struct EvaluateResponse: Decodable {
    let activityId: Int
    let date: String
    let report: String
    enum CodingKeys: String, CodingKey {
        case activityId = "activity_id", date, report
    }
}

struct ChatResponse: Decodable {
    let response: String
}

// MARK: - Errors

enum ServerError: LocalizedError {
    case notConfigured
    case httpError(Int, String)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Server not configured. Go to Settings and enter your server URL and token."
        case .httpError(let code, let msg):
            return "Server error \(code): \(msg)"
        case .decodingError(let msg):
            return "Unexpected server response: \(msg)"
        }
    }
}

// MARK: - Client

class ServerClient {
    static let shared = ServerClient()

    private var baseURL: String { KeychainHelper.loadServerURL() ?? "" }
    private var token: String   { KeychainHelper.loadServerToken() ?? "" }

    // MARK: Generic request

    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        timeout: TimeInterval = 90
    ) async throws -> T {
        guard !baseURL.isEmpty, !token.isEmpty else {
            throw ServerError.notConfigured
        }
        guard let url = URL(string: baseURL + path) else {
            throw ServerError.notConfigured
        }

        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw ServerError.httpError(0, "No HTTP response")
        }
        guard http.statusCode == 200 else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["detail"] as? String } ?? "HTTP \(http.statusCode)"
            throw ServerError.httpError(http.statusCode, detail)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ServerError.decodingError(error.localizedDescription)
        }
    }

    // MARK: Endpoints

    func getStatus() async throws -> ServerStatus {
        try await request("/status")
    }

    func analyze(period: String) async throws -> AnalyzeResponse {
        try await request("/analyze", method: "POST", body: ["period": period], timeout: 120)
    }

    func coach(type: String) async throws -> CoachResponse {
        try await request("/coach", method: "POST", body: ["type": type, "upload": false], timeout: 120)
    }

    func evaluate(activityId: Int? = nil) async throws -> EvaluateResponse {
        var body: [String: Any] = [:]
        if let id = activityId { body["activity_id"] = id }
        return try await request("/evaluate", method: "POST", body: body, timeout: 120)
    }

    func chat(message: String) async throws -> String {
        let resp: ChatResponse = try await request("/chat", method: "POST", body: ["message": message], timeout: 60)
        return resp.response
    }

    func isReachable() async -> Bool {
        guard !baseURL.isEmpty,
              let url = URL(string: baseURL + "/health") else { return false }
        let req = URLRequest(url: url, timeoutInterval: 5)
        return (try? await URLSession.shared.data(for: req)) != nil
    }
}
