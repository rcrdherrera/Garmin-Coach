import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    private let readTypes: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKQuantityType(.heartRate),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.vo2Max),
        HKQuantityType(.bodyMass),
    ]

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestPermissions() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    // MARK: - Workouts

    func recentRuns(limit: Int = 20) async throws -> [WorkoutSummary] {
        let predicate = HKQuery.predicateForWorkouts(with: .running)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts.map { self.toSummary($0) })
            }
            store.execute(query)
        }
    }

    private func toSummary(_ workout: HKWorkout) -> WorkoutSummary {
        let distanceM = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
        let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
        let avgHR = workout.statistics(for: HKQuantityType(.heartRate))?
            .averageQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
        let elevation = (workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity)?
            .doubleValue(for: .meter())

        return WorkoutSummary(
            date: workout.startDate,
            durationMinutes: workout.duration / 60,
            distanceKm: distanceM / 1000,
            averageHR: avgHR,
            calories: calories,
            elevationGain: elevation
        )
    }

    // MARK: - Athlete metrics (fetched in parallel)

    func athleteMetrics() async throws -> AthleteMetrics {
        async let rhr = restingHR()
        async let vo2 = vo2Max()
        async let wt  = bodyWeight()
        return try await AthleteMetrics(restingHR: rhr, vo2max: vo2, weightKg: wt)
    }

    private func restingHR() async throws -> Double? {
        let type = HKQuantityType(.restingHeartRate)
        let start = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: stats?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min")))
            }
            store.execute(query)
        }
    }

    private func vo2Max() async throws -> Double? {
        let type = HKQuantityType(.vo2Max)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let val = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: HKUnit(from: "ml/kg·min"))
                continuation.resume(returning: val)
            }
            store.execute(query)
        }
    }

    private func bodyWeight() async throws -> Double? {
        let type = HKQuantityType(.bodyMass)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let kg = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            store.execute(query)
        }
    }
}
