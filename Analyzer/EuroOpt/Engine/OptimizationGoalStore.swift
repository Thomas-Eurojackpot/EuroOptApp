import Foundation

/// Thread-safe storage for the currently learned optimization profile.
/// The profile is kept in memory and persisted locally so learned weights
/// survive an application restart.
final class OptimizationGoalStore {

    static let shared = OptimizationGoalStore()

    private let lock = NSLock()
    private let defaults = UserDefaults.standard
    private let key = "EuroOpt.learnedOptimizationGoal"

    private var storedGoal: OptimizationGoal

    private init() {
        if let data = defaults.data(forKey: key),
           let profile = try? JSONDecoder().decode(LearnedGoalProfile.self, from: data) {
            storedGoal = profile.goal
        } else {
            storedGoal = OptimizationGoal()
        }
    }

    var currentGoal: OptimizationGoal {
        lock.lock()
        defer { lock.unlock() }
        return storedGoal
    }

    func update(_ goal: OptimizationGoal) {
        let normalized = Self.normalized(goal)

        lock.lock()
        storedGoal = normalized
        lock.unlock()

        let profile = LearnedGoalProfile(goal: normalized)
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: key)
        }
    }

    func reset() {
        update(OptimizationGoal())
    }

    private static func normalized(_ goal: OptimizationGoal) -> OptimizationGoal {
        let values = [
            max(0, goal.frequencyWeight),
            max(0, goal.pairWeight),
            max(0, goal.evenOddWeight),
            max(0, goal.highLowWeight),
            max(0, goal.sumWeight),
            max(0, goal.gapWeight)
        ]

        let total = values.reduce(0, +)
        guard total > 0 else { return OptimizationGoal() }

        let factor = 100.0 / total

        return OptimizationGoal(
            frequencyWeight: values[0] * factor,
            pairWeight: values[1] * factor,
            evenOddWeight: values[2] * factor,
            highLowWeight: values[3] * factor,
            sumWeight: values[4] * factor,
            gapWeight: values[5] * factor
        )
    }

    private struct LearnedGoalProfile: Codable {
        let frequency: Double
        let pair: Double
        let evenOdd: Double
        let highLow: Double
        let sum: Double
        let gap: Double

        init(goal: OptimizationGoal) {
            frequency = goal.frequencyWeight
            pair = goal.pairWeight
            evenOdd = goal.evenOddWeight
            highLow = goal.highLowWeight
            sum = goal.sumWeight
            gap = goal.gapWeight
        }

        var goal: OptimizationGoal {
            OptimizationGoal(
                frequencyWeight: frequency,
                pairWeight: pair,
                evenOddWeight: evenOdd,
                highLowWeight: highLow,
                sumWeight: sum,
                gapWeight: gap
            )
        }
    }
}
