//
//  ScoreEngine.swift
//  EuroOpt
//
//  Alpha 6.4
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

    private let goal = OptimizationGoal()

    private lazy var totalWeight: Double = {
        goal.frequencyWeight +
        goal.pairWeight +
        goal.evenOddWeight +
        goal.highLowWeight +
        goal.sumWeight +
        goal.gapWeight
    }()

    // MARK: - Public Methods

    @inline(__always)
    func score(
        ticket: Ticket,
        draws: [EuroJackpotDraw]
    ) -> Double {

        let totalWeight = totalWeight

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
