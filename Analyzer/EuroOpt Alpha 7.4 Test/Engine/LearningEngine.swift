//
//  LearningEngine.swift
//  EuroOpt
//
//  Alpha 7.0
//

import Foundation

final class LearningEngine {

    private let evolution = EvolutionEngine()
    private let backtest = BacktestEngine()

    func learn(
        draws: [EuroJackpotDraw],
        candidateCount: Int,
        recommendationCount: Int,
        generations: Int
    ) -> OptimizationGoal {

        let startGoal = OptimizationGoalStore.shared.currentGoal

        let bestGoal = evolution.evolve(
            startGoal: startGoal,
            generations: generations
        ) { goal in

            let results = backtest.run(
                draws: draws,
                candidateCount: candidateCount,
                recommendationCount: recommendationCount,
                goal: goal
            ) { _, _, _ in }

            return BacktestStatistics.calculate(
                from: results
            )

        }

        // Neue optimale Gewichtung dauerhaft übernehmen
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
