import SwiftData
import Foundation

// MARK: - SwiftData Models

@Model
final class DailySnapshot {
    var date: String
    var hrv: Int?
    var hrvWeeklyAvg: Int?
    var hrvStatus: String?
    var hrvBaselineLow: Int?
    var hrvBaselineHigh: Int?
    var sleepScore: Int?
    var sleepDurationH: Double?
    var sleepDeepH: Double?
    var sleepRemH: Double?
    var rhr: Int?
    var bodyBatteryHigh: Int?
    var bodyBatteryLow: Int?
    var readinessScore: Int?
    var readinessLevel: String?
    var acuteLoad: Double?
    var cachedAt: Date

    init(date: String) {
        self.date = date
        self.cachedAt = .now
    }

    func update(from s: TrendSnapshot) {
        hrv = s.hrv
        hrvWeeklyAvg = s.hrvWeeklyAvg
        hrvStatus = s.hrvStatus
        hrvBaselineLow = s.hrvBaselineLow
        hrvBaselineHigh = s.hrvBaselineHigh
        sleepScore = s.sleepScore
        sleepDurationH = s.sleepDurationH
        sleepDeepH = s.sleepDeepH
        sleepRemH = s.sleepRemH
        rhr = s.rhr
        bodyBatteryHigh = s.bodyBatteryHigh
        bodyBatteryLow = s.bodyBatteryLow
        readinessScore = s.readinessScore
        readinessLevel = s.readinessLevel
        acuteLoad = s.acuteLoad
        cachedAt = .now
    }
}

@Model
final class CachedActivity {
    var activityId: Int
    var name: String
    var type: String
    var distanceKm: Double
    var durationMin: Double
    var startTimeLocal: String
    var avgHR: Int?
    var maxHR: Int?
    var avgCadence: Double?
    var calories: Int?
    var aerobicTE: Double?
    var trainingLoad: Double?
    var avgSpeedMs: Double?
    var hrZ1s: Double?
    var hrZ2s: Double?
    var hrZ3s: Double?
    var hrZ4s: Double?
    var hrZ5s: Double?
    var cachedAt: Date

    init(from a: ActivitySummary) {
        activityId = a.activityId
        name = a.name ?? "Unknown"
        type = a.type ?? "unknown"
        distanceKm = a.distanceKm ?? 0
        durationMin = a.durationMin ?? 0
        startTimeLocal = a.startTimeLocal ?? ""
        avgHR = a.averageHR
        maxHR = a.maxHR
        avgCadence = a.avgCadence
        calories = a.calories
        aerobicTE = a.aerobicTE
        trainingLoad = a.trainingLoad
        avgSpeedMs = a.avgSpeedMs
        hrZ1s = a.hrZ1s
        hrZ2s = a.hrZ2s
        hrZ3s = a.hrZ3s
        hrZ4s = a.hrZ4s
        hrZ5s = a.hrZ5s
        cachedAt = .now
    }

    func update(from a: ActivitySummary) {
        name = a.name ?? name
        type = a.type ?? type
        distanceKm = a.distanceKm ?? distanceKm
        durationMin = a.durationMin ?? durationMin
        startTimeLocal = a.startTimeLocal ?? startTimeLocal
        avgHR = a.averageHR
        maxHR = a.maxHR
        avgCadence = a.avgCadence
        calories = a.calories
        aerobicTE = a.aerobicTE
        trainingLoad = a.trainingLoad
        avgSpeedMs = a.avgSpeedMs
        hrZ1s = a.hrZ1s
        hrZ2s = a.hrZ2s
        hrZ3s = a.hrZ3s
        hrZ4s = a.hrZ4s
        hrZ5s = a.hrZ5s
        cachedAt = .now
    }

    var isRun: Bool {
        ["running", "treadmill_running", "track_running"].contains(type)
    }

    var activityIcon: String {
        switch type {
        case "running", "treadmill_running", "track_running": return "figure.run"
        case "strength_training", "fitness_equipment":         return "dumbbell.fill"
        case "cycling", "virtual_ride":                        return "bicycle"
        case "swimming":                                       return "figure.pool.swim"
        case "walking":                                        return "figure.walk"
        default:                                               return "figure.mixed.cardio"
        }
    }

    // Returns "M:SS /km" pace string from avg speed in m/s
    var pacePerKm: String? {
        guard let speed = avgSpeedMs, speed > 0 else { return nil }
        let secsPerKm = 1000.0 / speed
        let mins = Int(secsPerKm) / 60
        let secs = Int(secsPerKm) % 60
        return String(format: "%d:%02d /km", mins, secs)
    }
}

// MARK: - Cache Sync

@MainActor
final class CacheManager {
    static let shared = CacheManager()

    private var lastTrendsSync: Date?
    private var lastActivitiesSync: Date?

    func syncTrendsIfNeeded(context: ModelContext) async {
        guard shouldRefetch(lastTrendsSync, interval: 3600) else { return }
        do {
            let response = try await ServerClient.shared.getTrends(days: 30)
            try storeTrends(response.snapshots, in: context)
            lastTrendsSync = .now
        } catch {}
    }

    func syncActivitiesIfNeeded(context: ModelContext) async {
        guard shouldRefetch(lastActivitiesSync, interval: 3600) else { return }
        do {
            let activities = try await ServerClient.shared.getActivities(limit: 300)
            try storeActivities(activities, in: context)
            lastActivitiesSync = .now
        } catch {}
    }

    func forceSyncActivities(context: ModelContext) async {
        lastActivitiesSync = nil
        await syncActivitiesIfNeeded(context: context)
    }

    private func shouldRefetch(_ last: Date?, interval: TimeInterval) -> Bool {
        guard let last else { return true }
        return Date().timeIntervalSince(last) > interval
    }

    private func storeTrends(_ snapshots: [TrendSnapshot], in context: ModelContext) throws {
        for s in snapshots {
            let dateStr = s.date
            var desc = FetchDescriptor<DailySnapshot>(
                predicate: #Predicate<DailySnapshot> { $0.date == dateStr }
            )
            desc.fetchLimit = 1
            if let existing = try context.fetch(desc).first {
                existing.update(from: s)
            } else {
                let snap = DailySnapshot(date: s.date)
                snap.update(from: s)
                context.insert(snap)
            }
        }
        try context.save()
    }

    private func storeActivities(_ activities: [ActivitySummary], in context: ModelContext) throws {
        for a in activities {
            let actId = a.activityId
            var desc = FetchDescriptor<CachedActivity>(
                predicate: #Predicate<CachedActivity> { $0.activityId == actId }
            )
            desc.fetchLimit = 1
            if let existing = try context.fetch(desc).first {
                existing.update(from: a)
            } else {
                context.insert(CachedActivity(from: a))
            }
        }
        try context.save()
    }
}
