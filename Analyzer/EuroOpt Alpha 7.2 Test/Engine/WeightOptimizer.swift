//
//  WeightOptimizer.swift
//  EuroOpt
//
//  Alpha 7.0
//

import Foundation

final class WeightOptimizer {

    private let mutator = WeightMutator()

    func optimize(
        startGoal: OptimizationGoal,
        iterations: Int
    ) -> OptimizationGoal {

        var bestGoal = startGoal

        for _ in 0..<iterations {

            let candidate = mutator.mutate(goal: bestGoal)

            // Hier erfolgt im nächsten Schritt
            // die Bewertung per Backtest.
            // Vorerst übernehmen wir jede Mutation.

            bestGoal = candidate

        }

        return bestGoal

    }

}
