//
//  ScoreEngine.swift
//  EuroOpt
//
//  Alpha 7.2 Test
//

import Foundation

final class ScoreEngine {

    // MARK: - Properties

    private let frequencyScore = FrequencyScore()
    private let pairScore = PairScore()
    private let evenOddScore = EvenOddScore()
    private let highLowScore = HighLowScore()
    private let sumScore = SumScore()
    private let gapScore = GapScore()

    private var goal: OptimizationGoal

    private static var diagnosticsPrinted = false

    // MARK: - Initializer

    init(goal: OptimizationGoal = OptimizationGoal()) {

        self.goal = goal

    }

    // MARK: - Public

    func updateGoal(_ goal: OptimizationGoal) {

        self.goal = goal

    }

    @inline(__always)
    func score(
        ticket: Ticket,
        draws: [EuroJackpotDraw]
    ) -> Double {

        let totalWeight =
            goal.frequencyWeight +
            goal.pairWeight +
            goal.evenOddWeight +
            goal.highLowWeight +
            goal.sumWeight +
            goal.gapWeight

        guard totalWeight > 0 else {
            return 0
        }

        let numbers = ticket.numbers
        let euroNumbers = ticket.euroNumbers

        var weightedScore = 0.0

        let diagnose = !Self.diagnosticsPrinted

        var start = CFAbsoluteTimeGetCurrent()

        weightedScore +=
            frequencyScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            ) * goal.frequencyWeight

        if diagnose {
            print(String(format: "⏱ Frequency : %.5f s",
                         CFAbsoluteTimeGetCurrent() - start))
        }

        start = CFAbsoluteTimeGetCurrent()

        weightedScore +=
            pairScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            ) * goal.pairWeight

        if diagnose {
            print(String(format: "⏱ Pair      : %.5f s",
                         CFAbsoluteTimeGetCurrent() - start))
        }

        start = CFAbsoluteTimeGetCurrent()

        weightedScore +=
            evenOddScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            ) * goal.evenOddWeight

        if diagnose {
            print(String(format: "⏱ Even/Odd  : %.5f s",
                         CFAbsoluteTimeGetCurrent() - start))
        }

        start = CFAbsoluteTimeGetCurrent()

        weightedScore +=
            highLowScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            ) * goal.highLowWeight

        if diagnose {
            print(String(format: "⏱ High/Low  : %.5f s",
                         CFAbsoluteTimeGetCurrent() - start))
        }

        start = CFAbsoluteTimeGetCurrent()

        weightedScore +=
            sumScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            ) * goal.sumWeight

        if diagnose {
            print(String(format: "⏱ Sum       : %.5f s",
                         CFAbsoluteTimeGetCurrent() - start))
        }

        start = CFAbsoluteTimeGetCurrent()

        weightedScore +=
            gapScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            ) * goal.gapWeight

        if diagnose {

            print(String(format: "⏱ Gap       : %.5f s",
                         CFAbsoluteTimeGetCurrent() - start))

            print("--------------------------------")

            Self.diagnosticsPrinted = true

        }

        return weightedScore / totalWeight

    }

}
