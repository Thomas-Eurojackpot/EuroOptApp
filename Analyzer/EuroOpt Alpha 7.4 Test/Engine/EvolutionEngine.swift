//
//  EvolutionEngine.swift
//  EuroOpt
//
//  Alpha 7.0
//

import Foundation

final class EvolutionEngine {

    private let mutator = WeightMutator()
    private let fitnessCalculator = FitnessCalculator()

    func evolve(
        startGoal: OptimizationGoal,
        generations: Int,
        evaluate: (OptimizationGoal) -> BacktestStatistics
    ) -> OptimizationGoal {

        var bestGoal = startGoal
        var bestFitness = -Double.infinity

        for generation in 1...generations {

            let candidate = mutator.mutate(goal: bestGoal)

            let statistics = evaluate(candidate)

            let fitness = fitnessCalculator.fitness(
                from: statistics
            )

            if fitness > bestFitness {

                bestFitness = fitness
                bestGoal = candidate

                print("")
                print("🧬 Generation \(generation)")
                print(String(format: "🏆 Fitness : %.2f", fitness))
                print(String(format: "Frequency : %.2f", candidate.frequencyWeight))
                print(String(format: "Pair      : %.2f", candidate.pairWeight))
                print(String(format: "Even/Odd  : %.2f", candidate.evenOddWeight))
                print(String(format: "High/Low  : %.2f", candidate.highLowWeight))
                print(String(format: "Sum       : %.2f", candidate.sumWeight))
                print(String(format: "Gap       : %.2f", candidate.gapWeight))

            }

        }

        return bestGoal

    }

}
