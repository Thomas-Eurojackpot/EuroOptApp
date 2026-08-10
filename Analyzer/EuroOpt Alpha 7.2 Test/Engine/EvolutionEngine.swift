//
//  EvolutionEngine.swift
//  EuroOpt
//
//  Alpha 7.3
//

import Foundation

final class EvolutionEngine {

    private let mutator = WeightMutator()
    private let fitnessCalculator = FitnessCalculator()

    /// Anzahl Kandidaten je Generation
    private let populationSize = 40

    func evolve(
        startGoal: OptimizationGoal,
        generations: Int,
        evaluate: (OptimizationGoal) -> BacktestStatistics
    ) -> OptimizationGoal {

        // Champion bestimmen

        var champion = startGoal

        var championStatistics = evaluate(champion)

        var championFitness =
            fitnessCalculator.fitness(
                from: championStatistics
            )

        print("")
        print("🏁 Startfitness: \(String(format: "%.2f", championFitness))")

        for generation in 1...generations {

            var generationWinner = champion
            var generationFitness = championFitness
            var generationStatistics = championStatistics

            for _ in 0..<populationSize {

                let candidate = mutator.mutate(
                    goal: champion
                )

                let statistics = evaluate(
                    candidate
                )

                let fitness =
                    fitnessCalculator.fitness(
                        from: statistics
                    )

                if fitness > generationFitness {

                    generationWinner = candidate
                    generationFitness = fitness
                    generationStatistics = statistics

                }

            }

            // Champion ersetzen

            if generationFitness > championFitness {

                champion = generationWinner
                championFitness = generationFitness
                championStatistics = generationStatistics

                print("")
                print("🧬 Generation \(generation)")
                print(String(format: "🏆 Fitness : %.2f", championFitness))
                print(String(format: "Ø Treffer : %.2f", championStatistics.averageHits))
                print(String(format: "Ø Euro    : %.2f", championStatistics.averageEuroHits))
                print(String(format: "EQI       : %.2f", championStatistics.averageEQI))

                print(String(format: "Frequency : %.2f", champion.frequencyWeight))
                print(String(format: "Pair      : %.2f", champion.pairWeight))
                print(String(format: "Even/Odd  : %.2f", champion.evenOddWeight))
                print(String(format: "High/Low  : %.2f", champion.highLowWeight))
                print(String(format: "Sum       : %.2f", champion.sumWeight))
                print(String(format: "Gap       : %.2f", champion.gapWeight))

            }

        }

        return champion

    }

}
