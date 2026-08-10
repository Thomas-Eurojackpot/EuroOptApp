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

    // Nur für Diagnose
    private static var diagnosticsPrinted = false

    // MARK: - Public

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

        // Diagnose nur einmal ausgeben
        let diagnose = !Self.diagnosticsPrinted

        var t0 = Date()

        weightedScore +=
            frequencyScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            ) * goal.frequencyWeight

        if diagnose {
            print(String(format: "Frequency : %.4f s",
                         Date().timeIntervalSince(t0)))
        }

        t0 = Date()

        weightedScore +=
            pairScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            ) * goal.pairWeight

        if diagnose {
            print(String(format: "Pair      : %.4f s",
                         Date().timeIntervalSince(t0)))
        }

        t0 = Date()

        weightedScore +=
            evenOddScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            ) * goal.evenOddWeight

        if diagnose {
            print(String(format: "EvenOdd   : %.4f s",
                         Date().timeIntervalSince(t0)))
        }

        t0 = Date()

        weightedScore +=
            highLowScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            ) * goal.highLowWeight

        if diagnose {
            print(String(format: "HighLow   : %.4f s",
                         Date().timeIntervalSince(t0)))
        }

        t0 = Date()

        weightedScore +=
            sumScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            ) * goal.sumWeight

        if diagnose {
            print(String(format: "Sum       : %.4f s",
                         Date().timeIntervalSince(t0)))
        }

        t0 = Date()

        weightedScore +=
            gapScore.calculate(
                numbers: numbers,
                euroNumbers: euroNumbers,
                draws: draws
            ) * goal.gapWeight

        if diagnose {

            print(String(format: "Gap       : %.4f s",
                         Date().timeIntervalSince(t0)))

            print("--------------------------------")

            Self.diagnosticsPrinted = true

        }

        return weightedScore / totalWeight

    }

}
