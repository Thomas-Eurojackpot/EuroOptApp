//
//  ScoreEngine.swift
//  EuroOpt
//
//  Alpha 5.1
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

    // MARK: - Public Methods

    func score(
        ticket: Ticket,
        draws: [EuroJackpotDraw]
    ) -> Double {

        let frequency = frequencyScore.calculate(
            numbers: ticket.numbers,
            euroNumbers: ticket.euroNumbers,
            draws: draws
        )

        let pair = pairScore.calculate(
            numbers: ticket.numbers,
            euroNumbers: ticket.euroNumbers,
            draws: draws
        )

        let evenOdd = evenOddScore.calculate(
            numbers: ticket.numbers,
            euroNumbers: ticket.euroNumbers,
            draws: draws
        )

        let highLow = highLowScore.calculate(
            numbers: ticket.numbers,
            euroNumbers: ticket.euroNumbers,
            draws: draws
        )

        let sum = sumScore.calculate(
            numbers: ticket.numbers,
            euroNumbers: ticket.euroNumbers,
            draws: draws
        )

        let gap = gapScore.calculate(
            numbers: ticket.numbers,
            euroNumbers: ticket.euroNumbers,
            draws: draws
        )

        let weightedScore =
            frequency * goal.frequencyWeight +
            pair * goal.pairWeight +
            evenOdd * goal.evenOddWeight +
            highLow * goal.highLowWeight +
            sum * goal.sumWeight +
            gap * goal.gapWeight

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

        return weightedScore / totalWeight

    }

}
