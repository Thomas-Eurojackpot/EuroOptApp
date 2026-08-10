//
//  BenchmarkEngine.swift
//  EuroOpt
//
//  Alpha 6.4
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

        var totalScore = 0.0
        var bestScore = -Double.infinity
        var worstScore = Double.infinity

        for ticket in tickets {

            let score = scoreEngine.score(
                ticket: ticket,
                draws: draws
            )

            totalScore += score

            if score > bestScore {
                bestScore = score
            }

            if score < worstScore {
                worstScore = score
            }

        }

        return BenchmarkResult(
            ticketCount: tickets.count,
            averageScore: totalScore / Double(tickets.count),
            bestScore: bestScore,
            worstScore: worstScore
        )

    }

}
