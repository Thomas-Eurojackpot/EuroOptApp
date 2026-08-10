//
//  ScoreEngine.swift
//  EuroOpt
//
//  Alpha 6.5
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

        guard totalWeight > 0 else {
            return 0
        }

        let numbers = ticket.numbers
        let euroNumbers = ticket.euroNumbers

        let frequency =
            frequencyScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            )

        let pair =
            pairScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            )

        let evenOdd =
            evenOddScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            )

        let highLow =
            highLowScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            )

        let sum =
            sumScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            )

        let gap =
            gapScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            )

        let weightedScore =
            frequency * goal.frequencyWeight +
            pair * goal.pairWeight +
            evenOdd * goal.evenOddWeight +
            highLow * goal.highLowWeight +
            sum * goal.sumWeight +
            gap * goal.gapWeight

        return weightedScore / totalWeight

    }

}
