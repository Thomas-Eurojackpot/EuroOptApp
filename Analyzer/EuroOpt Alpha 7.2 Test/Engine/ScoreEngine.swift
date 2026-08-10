//
//  ScoreEngine.swift
//  EuroOpt
//
//  Alpha 7.4
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

        weightedScore +=
            frequencyScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            ) * goal.frequencyWeight

        weightedScore +=
            pairScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            ) * goal.pairWeight

        weightedScore +=
            evenOddScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            ) * goal.evenOddWeight

        weightedScore +=
            highLowScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            ) * goal.highLowWeight

        weightedScore +=
            sumScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            ) * goal.sumWeight

        weightedScore +=
            gapScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            ) * goal.gapWeight

        return weightedScore / totalWeight

    }

}
