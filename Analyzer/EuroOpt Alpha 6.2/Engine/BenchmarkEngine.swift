//
//  BenchmarkEngine.swift
//  EuroOpt
//
//  Alpha 1.0
//

import Foundation

struct BenchmarkResult {

    let ticketCount: Int
    let averageScore: Double
    let bestScore: Double
    let worstScore: Double

}

final class BenchmarkEngine {

    private let scoreEngine = ScoreEngine()

    func analyze(
        tickets: [Ticket],
        draws: [EuroJackpotDraw]
    ) -> BenchmarkResult {

        guard !tickets.isEmpty else {

            return BenchmarkResult(
                ticketCount: 0,
                averageScore: 0,
                bestScore: 0,
                worstScore: 0
            )

        }

        let scores = tickets.map {

            scoreEngine.score(
                ticket: $0,
                draws: draws
            )

        }

        let average =
            scores.reduce(0, +) /
            Double(scores.count)

        return BenchmarkResult(

            ticketCount: tickets.count,

            averageScore: average,

            bestScore: scores.max() ?? 0,

            worstScore: scores.min() ?? 0

        )

    }

}
