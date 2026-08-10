//
//  OptimizationGoalStore.swift
//  EuroOpt
//
//  Alpha 7.0
//

import Foundation

final class OptimizationGoalStore {

    static let shared = OptimizationGoalStore()

    private init() {}

    private(set) var currentGoal = OptimizationGoal()

    func update(
        _ goal: OptimizationGoal
    ) {

        currentGoal = goal

        print("")
        print("🧠 Neue Gewichtung übernommen")
        print(String(format: "Frequency : %.2f", goal.frequencyWeight))
        print(String(format: "Pair      : %.2f", goal.pairWeight))
        print(String(format: "Even/Odd  : %.2f", goal.evenOddWeight))
        print(String(format: "High/Low  : %.2f", goal.highLowWeight))
        print(String(format: "Sum       : %.2f", goal.sumWeight))
        print(String(format: "Gap       : %.2f", goal.gapWeight))
        print("")

    }

}
