//
//  LearningEngine.swift
//  EuroOpt
//
//  Alpha 7.3
//

import Foundation

final class LearningEngine {

    private let evolution = EvolutionEngine()
    private let backtest = BacktestEngine()

    // Schneller Lernmodus
    private let learningCandidateCount = 200
    private let learningRecommendationCount = 8

    func learn(
        draws: [EuroJackpotDraw],
        candidateCount: Int,
        recommendationCount: Int,
        generations: Int
    ) -> OptimizationGoal {

        let startGoal = OptimizationGoalStore.shared.currentGoal

        print("")
        print("===================================")
        print("🧠 EUROOPT LEARNING")
        print("===================================")
        print("Generationen : \(generations)")
        print("Population   : 40")
        print("===================================")

        let bestGoal = evolution.evolve(
            startGoal: startGoal,
            generations: generations
        ) { goal in

            let results = self.backtest.run(
                draws: draws,
                candidateCount: learningCandidateCount,
                recommendationCount: learningRecommendationCount,
                goal: goal,
                learningMode: true
            ) { _, _, _ in }

            return BacktestStatistics.calculate(
                from: results
            )

        }

        OptimizationGoalStore.shared.update(bestGoal)

        print("")
        print("===================================")
        print("🧠 LERNPHASE BEENDET")
        print("===================================")
        print(String(format: "Frequency : %.2f", bestGoal.frequencyWeight))
        print(String(format: "Pair      : %.2f", bestGoal.pairWeight))
        print(String(format: "Even/Odd  : %.2f", bestGoal.evenOddWeight))
        print(String(format: "High/Low  : %.2f", bestGoal.highLowWeight))
        print(String(format: "Sum       : %.2f", bestGoal.sumWeight))
        print(String(format: "Gap       : %.2f", bestGoal.gapWeight))
        print("===================================")

        return bestGoal

    }

}
