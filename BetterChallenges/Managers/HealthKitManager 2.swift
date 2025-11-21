//
//  HealthKitManager.swift
//  BetterChallenges
//
//  Created by Codex on 2025-11-19.
//

import Foundation
import HealthKit

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case noSummaryFound

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Health data is not available on this device."
        case .authorizationDenied:
            return "Health access was denied."
        case .noSummaryFound:
            return "No activity summary is available for today."
        }
    }
}

final class HealthKitManager {
    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        let readTypes: Set = [HKObjectType.activitySummaryType()]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard success else {
                    continuation.resume(throwing: HealthKitError.authorizationDenied)
                    return
                }
                continuation.resume()
            }
        }
    }

    func currentPermissionStatus() -> PermissionStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            return .denied(message: "Health data is not available on this device.")
        }

        let status = healthStore.authorizationStatus(for: HKObjectType.activitySummaryType())
        switch status {
        case .notDetermined:
            return .notDetermined
        case .sharingAuthorized:
            return .granted
        case .sharingDenied:
            return .denied(message: "Health access was denied. Update this in Settings.")
        @unknown default:
            return .denied(message: "Health permission status is unknown.")
        }
    }

    func fetchTodayRings() async throws -> FitnessRingSnapshot {
        let startDate = calendar.startOfDay(for: Date())
        guard let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) else {
            throw HealthKitError.noSummaryFound
        }

        var startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
        startComponents.calendar = calendar
        var endComponents = calendar.dateComponents([.year, .month, .day], from: endDate)
        endComponents.calendar = calendar
        let predicate = HKQuery.predicate(forActivitySummariesBetweenStart: startComponents, end: endComponents)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let summary = summaries?.first else {
                    continuation.resume(throwing: HealthKitError.noSummaryFound)
                    return
                }

                guard let snapshot = FitnessRingSnapshot(summary: summary) else {
                    continuation.resume(throwing: HealthKitError.noSummaryFound)
                    return
                }
                continuation.resume(returning: snapshot)
            }

            self.healthStore.execute(query)
        }
    }
}

private extension FitnessRingSnapshot {
    init?(summary: HKActivitySummary) {
        let energyUnit = HKUnit.largeCalorie()
        let timeUnit = HKUnit.minute()

        let moveGoal = summary.activeEnergyBurnedGoal.doubleValue(for: energyUnit)
        let moveValue = summary.activeEnergyBurned.doubleValue(for: energyUnit)
        let exerciseGoal = summary.appleExerciseTimeGoal.doubleValue(for: timeUnit)
        let exerciseValue = summary.appleExerciseTime.doubleValue(for: timeUnit)
        let standGoal = summary.appleStandHoursGoal.doubleValue(for: HKUnit.count())
        let standValue = summary.appleStandHours.doubleValue(for: HKUnit.count())

        guard moveGoal > 0, exerciseGoal > 0, standGoal > 0 else {
            return nil
        }

        self.init(
            date: Date(),
            move: RingMetric(title: "Move", value: moveValue, goal: moveGoal, unitDisplay: "kcal"),
            exercise: RingMetric(title: "Exercise", value: exerciseValue, goal: exerciseGoal, unitDisplay: "min"),
            stand: RingMetric(title: "Stand", value: standValue, goal: standGoal, unitDisplay: "hrs")
        )
    }
}
