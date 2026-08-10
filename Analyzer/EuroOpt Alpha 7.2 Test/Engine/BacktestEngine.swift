//
//  BacktestEngine.swift
//  EuroOpt
//
//  Alpha 7.4
//

import Foundation

final class BacktestEngine {

    func run(
        draws: [EuroJackpotDraw],
        candidateCount: Int,
        recommendationCount: Int,
        goal: OptimizationGoal = OptimizationGoal(),
        learningMode: Bool = false,
        progress: @escaping (_ progress: Double,
                             _ current: Int,
                             _ total: Int) -> Void
    ) -> [BacktestResult] {

        // Lernmodus massiv verkleinern
        let trainingSize = learningMode ? 20 : 50

        let maxTests = learningMode
            ? min(5, draws.count - trainingSize)
            : min(50, draws.count - trainingSize)

        guard draws.count > trainingSize else {
            return []
        }

        let session = BacktestSession(
            trainingDraws: Array(draws.prefix(trainingSize)),
            goal: goal
        )

        var results: [BacktestResult] = []
        results.reserveCapacity(maxTests)

        for index in trainingSize..<(trainingSize + maxTests) {

            let targetDraw = draws[index]

            let result = runSingleTest(
                session: session,
                targetDraw: targetDraw,
                candidateCount: candidateCount,
                recommendationCount: recommendationCount,
                goal: goal,
                learningMode: learningMode
            )

            results.append(result)

            session.add(draw: targetDraw)

            let current = index - trainingSize + 1

            progress(
                Double(current) / Double(maxTests),
                current,
                maxTests
            )

        }

        return results

    }

    // MARK: - Private

    private func runSingleTest(
        session: BacktestSession,
        targetDraw: EuroJackpotDraw,
        candidateCount: Int,
        recommendationCount: Int,
        goal: OptimizationGoal,
        learningMode: Bool
    ) -> BacktestResult {

        let candidates = session.generator.generate(
            count: candidateCount,
            draws: session.trainingDraws,
            hillClimbingIterations: learningMode ? 6 : 40
        )

        let best = session.optimizer.bestTickets(
            from: candidates,
            draws: session.trainingDraws,
            goal: goal,
            limit: recommendationCount
        )

        var ticketResults: [BacktestTicketResult] = []

        var bestHits = 0
        var bestEuroHits = 0

        var totalHits = 0
        var totalEuroHits = 0
        var totalEQI = 0.0

        for (index, ticket) in best.enumerated() {

            let hits = Set(ticket.ticket.numbers)
                .intersection(targetDraw.numbers)
                .count

            let euroHits = Set(ticket.ticket.euroNumbers)
                .intersection(targetDraw.euroNumbers)
                .count

            ticketResults.append(
                BacktestTicketResult(
                    rank: index + 1,
                    hits: hits,
                    euroHits: euroHits,
                    eqi: ticket.score
                )
            )

            bestHits = max(bestHits, hits)
            bestEuroHits = max(bestEuroHits, euroHits)

            totalHits += hits
            totalEuroHits += euroHits
            totalEQI += ticket.score

        }

        return BacktestResult(
            drawDate: targetDraw.date,
            recommendationCount: recommendationCount,
            ticketResults: ticketResults,
            bestHits: bestHits,
            bestEuroHits: bestEuroHits,
            averageHits: Double(totalHits) / Double(recommendationCount),
            averageEuroHits: Double(totalEuroHits) / Double(recommendationCount),
            averageEQI: totalEQI / Double(recommendationCount),
            testedTickets: recommendationCount
        )

    }

}
