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
    let staleFields: [String]?   // fields backfilled from SQLite (not live API)

    enum CodingKeys: String, CodingKey {
        case date, bodyBattery = "body_battery", hrv, readiness
        case trainingStatus = "training_status", sleep, rhr, stress
        case staleFields = "_stale_fields"
    }

    var hasStaleRecoveryOrSleep: Bool {
        guard let fields = staleFields else { return false }
        return fields.contains("readiness") || fields.contains("sleep")
    }
}

struct TrendSnapshot: Decodable {
    let date: String
    let hrv: Int?
    let hrvWeeklyAvg: Int?
    let hrvStatus: String?
    let hrvBaselineLow: Int?
    let hrvBaselineHigh: Int?
    let sleepScore: Int?
    let sleepDurationH: Double?
    let sleepDeepH: Double?
    let sleepRemH: Double?
    let rhr: Int?
    let bodyBatteryHigh: Int?
    let bodyBatteryLow: Int?
    let readinessScore: Int?
    let readinessLevel: String?
    let acuteLoad: Double?

    enum CodingKeys: String, CodingKey {
        case date, hrv
        case hrvWeeklyAvg = "hrv_weekly_avg"
        case hrvStatus = "hrv_status"
        case hrvBaselineLow = "hrv_baseline_low"
        case hrvBaselineHigh = "hrv_baseline_high"
        case sleepScore = "sleep_score"
        case sleepDurationH = "sleep_duration_h"
        case sleepDeepH = "sleep_deep_h"
        case sleepRemH = "sleep_rem_h"
        case rhr
        case bodyBatteryHigh = "body_battery_high"
        case bodyBatteryLow = "body_battery_low"
        case readinessScore = "readiness_score"
        case readinessLevel = "readiness_level"
        case acuteLoad = "acute_load"
    }
}

struct TrendsResponse: Decodable {
    let snapshots: [TrendSnapshot]
}

struct ActivitySummary: Decodable, Identifiable {
    let activityId: Int
    let name: String?
    let type: String?
    let distanceKm: Double?
    let durationMin: Double?
    let startTimeLocal: String?
    let averageHR: Int?
    let maxHR: Int?
    let avgCadence: Double?
    let calories: Int?
    let aerobicTE: Double?
    let trainingLoad: Double?
    let avgSpeedMs: Double?
    let hrZ1s: Double?
    let hrZ2s: Double?
    let hrZ3s: Double?
    let hrZ4s: Double?
    let hrZ5s: Double?

    var id: Int { activityId }

    enum CodingKeys: String, CodingKey {
        case activityId, name, type
        case distanceKm = "distance_km"
        case durationMin = "duration_min"
        case startTimeLocal, averageHR, maxHR, avgCadence, calories
        case aerobicTE, trainingLoad, avgSpeedMs
        case hrZ1s, hrZ2s, hrZ3s, hrZ4s, hrZ5s
    }
}

struct AnalyzeResponse: Decodable {
    let period: String
    let report: String
    let conversationId: Int?
    let title: String?

    enum CodingKeys: String, CodingKey {
        case period, report, title
        case conversationId = "conversation_id"
    }
}

struct CoachResponse: Decodable {
    let date: String
    let type: String
    let brief: String
    let uploadedWorkouts: [UploadedWorkout]?
    let conversationId: Int?
    let title: String?

    enum CodingKeys: String, CodingKey {
        case date, type, brief, title
        case uploadedWorkouts = "uploaded_workouts"
        case conversationId = "conversation_id"
    }
}

struct UploadedWorkout: Decodable, Identifiable {
    let name: String
    let date: String
    let workoutId: Int?
    let scheduledId: Int?
    let error: String?

    var id: String { "\(name)-\(date)" }

    enum CodingKeys: String, CodingKey {
        case name, date, workoutId = "workout_id", scheduledId = "scheduled_id", error
    }
}

struct EvaluateResponse: Decodable {
    struct Metrics: Decodable {
        let acwr: Double?
        let ctl: Double?
        let atl: Double?
        let tsb: Double?
        let acuteLoad7d: Double?
        let chronicWeeklyAvg: Double?
        enum CodingKeys: String, CodingKey {
            case acwr, ctl, atl, tsb
            case acuteLoad7d = "acute_load_7d"
            case chronicWeeklyAvg = "chronic_weekly_avg"
        }
    }
    let activityId: Int
    let date: String
    let metrics: Metrics?
    let report: String
    enum CodingKeys: String, CodingKey {
        case activityId = "activity_id", date, metrics, report
    }
}

struct ChatResponse: Decodable {
    let response: String
}

struct RememberResponse: Decodable {
    let saved: String
    let file: String
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
        // Strip trailing slash to prevent double-slash URLs (e.g. http://host:8765//chat)
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        guard let url = URL(string: base + path) else {
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

    func syncToday() async throws {
        struct SyncResult: Decodable { let status: String }
        let _: SyncResult = try await request("/sync", method: "POST", timeout: 130)
    }

    func getTrends(days: Int = 30) async throws -> TrendsResponse {
        try await request("/trends?days=\(days)")
    }

    func getActivities(limit: Int = 30) async throws -> [ActivitySummary] {
        try await request("/activities?limit=\(limit)")
    }

    func analyze(period: String, activityType: String? = nil) async throws -> AnalyzeResponse {
        var body: [String: Any] = ["period": period]
        if let t = activityType { body["activity_type"] = t }
        return try await request("/analyze", method: "POST", body: body, timeout: 120)
    }

    func coach(type: String, upload: Bool = false, conversationId: Int? = nil) async throws -> CoachResponse {
        var body: [String: Any] = ["type": type, "upload": upload]
        if let cid = conversationId { body["conversation_id"] = cid }
        return try await request("/coach", method: "POST", body: body, timeout: 120)
    }

    func evaluate(activityId: Int? = nil) async throws -> EvaluateResponse {
        var body: [String: Any] = [:]
        if let id = activityId { body["activity_id"] = id }
        return try await request("/evaluate", method: "POST", body: body, timeout: 120)
    }

    func sendChat(conversationId: Int?, message: String, kind: String = "ask") async throws -> ChatTurnResponse {
        var body: [String: Any] = ["message": message, "kind": kind]
        if let cid = conversationId { body["conversation_id"] = cid }
        return try await request("/chat", method: "POST", body: body, timeout: 60)
    }

    func getConversations(kind: String? = nil) async throws -> [ConversationSummary] {
        let path = kind.map { "/conversations?kind=\($0)" } ?? "/conversations"
        let resp: ConversationListResponse = try await request(path)
        return resp.conversations
    }

    func getConversation(id: Int) async throws -> ConversationDetail {
        try await request("/conversations/\(id)")
    }

    func deleteConversation(id: Int) async throws {
        struct Empty: Decodable {}
        let _: Empty = try await request("/conversations/\(id)", method: "DELETE")
    }

    func remember(note: String) async throws {
        let _: RememberResponse = try await request("/remember", method: "POST", body: ["note": note])
    }

    func isReachable() async -> Bool {
        guard !baseURL.isEmpty,
              let url = URL(string: baseURL + "/health") else { return false }
        let req = URLRequest(url: url, timeoutInterval: 5)
        return (try? await URLSession.shared.data(for: req)) != nil
    }
}
