import Foundation

struct WorkoutSummary {
    let date: Date
    let durationMinutes: Double
    let distanceKm: Double
    let averageHR: Double?
    let calories: Double
    let elevationGain: Double?

    var paceMinPerKm: Double? {
        guard distanceKm > 0 else { return nil }
        return durationMinutes / distanceKm
    }

    var formattedPace: String {
        guard let pace = paceMinPerKm else { return "—" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}

struct AthleteMetrics {
    let restingHR: Double?
    let vo2max: Double?
    let weightKg: Double?
}
