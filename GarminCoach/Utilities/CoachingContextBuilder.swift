import Foundation

enum CoachingContextBuilder {

    static func build(runs: [WorkoutSummary], metrics: AthleteMetrics) -> String {
        [
            athleteSection(metrics: metrics),
            weeklyLoadSection(runs: runs),
            recentRunsSection(runs: runs),
            "What should my training focus be for the next 7 days?",
        ].joined(separator: "\n\n")
    }

    // MARK: - Sections

    private static func athleteSection(metrics: AthleteMetrics) -> String {
        var lines = ["## Athlete Metrics"]
        if let rhr = metrics.restingHR {
            lines.append("Resting HR (7-day avg): \(Int(rhr)) bpm")
        }
        if let v = metrics.vo2max {
            lines.append("VO2max: \(String(format: "%.1f", v)) ml/kg/min")
        }
        if let w = metrics.weightKg {
            lines.append("Weight: \(String(format: "%.1f", w)) kg")
        }
        return lines.joined(separator: "\n")
    }

    private static func weeklyLoadSection(runs: [WorkoutSummary]) -> String {
        let calendar = Calendar.current
        let now = Date.now

        func weekStats(_ weeksAgo: Int) -> (km: Double, count: Int) {
            let start = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: now)!
            let end   = weeksAgo == 0 ? now : calendar.date(byAdding: .weekOfYear, value: -(weeksAgo - 1), to: now)!
            let week  = runs.filter { $0.date >= start && $0.date < end }
            return (week.reduce(0) { $0 + $1.distanceKm }, week.count)
        }

        var lines = ["## Weekly Volume"]
        let labels = ["This week", "Last week", "2 weeks ago", "3 weeks ago"]
        for (i, label) in labels.enumerated() {
            let w = weekStats(i)
            lines.append("\(label): \(String(format: "%.1f", w.km)) km (\(w.count) runs)")
        }
        return lines.joined(separator: "\n")
    }

    private static func recentRunsSection(runs: [WorkoutSummary]) -> String {
        guard !runs.isEmpty else { return "## Recent Runs\nNo runs found in Apple Health." }

        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"

        var lines = ["## Recent Runs (most recent first)"]
        for run in runs.prefix(10) {
            var line = "\(fmt.string(from: run.date)): \(String(format: "%.1f", run.distanceKm)) km"
            line += " in \(String(format: "%.0f", run.durationMinutes)) min"
            line += " (\(run.formattedPace))"
            if let hr = run.averageHR {
                line += " — avg \(Int(hr)) bpm (Z\(hrZone(hr)))"
            }
            if let el = run.elevationGain, el > 10 {
                line += " +\(Int(el))m"
            }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func hrZone(_ bpm: Double) -> Int {
        switch bpm {
        case ..<147: return 1
        case 147..<163: return 2
        case 163..<174: return 3
        case 174..<182: return 4
        default: return 5
        }
    }
}
