//
//  ScoreEngineV2.swift
//  EuroOpt
//
//  Alpha 7.0
//

import Foundation

final class ScoreEngineV2 {

    // MARK: - Properties

    private let frequencyScore = FrequencyScore()
    private let pairScore = PairScore()
    private let evenOddScore = EvenOddScore()
    private let highLowScore = HighLowScore()
    private let sumScore = SumScore()

    // Variable Gewichte
    var weights: ScoreWeights = .default

    // MARK: - Public

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
            frequency * weights.frequency +
            pair * weights.pair +
            evenOdd * weights.evenOdd +
            highLow * weights.highLow +
            sum * weights.sum

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
