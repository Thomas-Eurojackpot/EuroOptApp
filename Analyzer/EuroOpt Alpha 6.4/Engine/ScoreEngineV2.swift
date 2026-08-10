//
//  ScoreEngineV2.swift
//  EuroOpt
//
//  Alpha 6.4
//

import Foundation

final class ScoreEngineV2 {

    // MARK: - Properties

    private let frequencyScore = FrequencyScore()
    private let pairScore = PairScore()
    private let evenOddScore = EvenOddScore()
    private let highLowScore = HighLowScore()
    private let sumScore = SumScore()

    private static let frequencyWeight = 0.30
    private static let pairWeight = 0.25
    private static let evenOddWeight = 0.15
    private static let highLowWeight = 0.15
    private static let sumWeight = 0.15

    // MARK: - Public Methods

    @inline(__always)
    func calculate(
        ticket: Ticket,
        draws: [EuroJackpotDraw]
    ) -> ScoreResult {

        let numbers = ticket.numbers
        let euroNumbers = ticket.euroNumbers

        let frequency = frequencyScore.calculate(
            numbers: numbers,
            euroNumbers: euroNumbers,
            draws: draws
        )

        let pair = pairScore.calculate(
            numbers: numbers,
            euroNumbers: euroNumbers,
            draws: draws
        )

        let evenOdd = evenOddScore.calculate(
            numbers: numbers,
            euroNumbers: euroNumbers,
            draws: draws
        )

        let highLow = highLowScore.calculate(
            numbers: numbers,
            euroNumbers: euroNumbers,
            draws: draws
        )

        let sum = sumScore.calculate(
            numbers: numbers,
            euroNumbers: euroNumbers,
            draws: draws
        )

        let total =
            frequency * Self.frequencyWeight +
            pair * Self.pairWeight +
            evenOdd * Self.evenOddWeight +
            highLow * Self.highLowWeight +
            sum * Self.sumWeight

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
