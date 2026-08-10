//
//  ScoreEngineV2.swift
//  EuroOpt
//

import Foundation

final class ScoreEngineV2 {

    // MARK: - Properties

    private let frequencyScore = FrequencyScore()
    private let pairScore = PairScore()
    private let evenOddScore = EvenOddScore()
    private let highLowScore = HighLowScore()
    private let sumScore = SumScore()

    // MARK: - Public Methods

    func calculate(
        ticket: Ticket,
        draws: [EuroJackpotDraw]
    ) -> ScoreResult {

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

        let total =
            frequency * 0.30 +
            pair * 0.25 +
            evenOdd * 0.15 +
            highLow * 0.15 +
            sum * 0.15

        return ScoreResult(
            totalScore: total,
            frequencyScore: frequency,
            pairScore: pair,
            evenOddScore: evenOdd,
            highLowScore: highLow,
            sumScore: sum
        )

    }

}
