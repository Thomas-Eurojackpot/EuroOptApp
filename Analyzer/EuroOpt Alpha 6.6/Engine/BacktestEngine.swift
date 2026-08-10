//
//  BacktestEngine.swift
//  EuroOpt
//
//  Alpha 6.6
//

import Foundation

final class BacktestEngine {

    // MARK: - Public

    func run(
        draws: [EuroJackpotDraw],
        candidateCount: Int,
        recommendationCount: Int,
        progress: @escaping (_ progress: Double,
                             _ current: Int,
                             _ total: Int) -> Void
    ) -> [BacktestResult] {

        guard draws.count > 100 else {
            print("❌ Zu wenige Ziehungen")
            return []
        }

        let start = Date()

        let totalTests = draws.count - 100

        var results: [BacktestResult] = []

        print("===================================")
        print("🧪 EUROOPT BACKTEST")
        print("===================================")

        let session = BacktestSession(
            trainingDraws: Array(draws.prefix(100))
        )

        for index in 100..<draws.count {

            let targetDraw = draws[index]

            let result = runSingleTest(
                session: session,
                targetDraw: targetDraw,
                candidateCount: candidateCount,
                recommendationCount: recommendationCount
            )

            results.append(result)

            session.add(draw: targetDraw)

            let current = index - 99

            progress(
                Double(current) / Double(totalTests),
                current,
                totalTests
            )

        }

        let statistics = BacktestStatistics.calculate(
            from: results
        )

        let prizeClasses = PrizeClassCalculator.calculate(
            from: results
        )

        let duration = Date().timeIntervalSince(start)

        print("")
        print("===================================")
        print("📊 BACKTEST AUSWERTUNG")
        print("===================================")

        print("Getestete Ziehungen : \(statistics.totalTests)")
        print(String(format: "Ø Haupttreffer      : %.2f", statistics.averageHits))
        print(String(format: "Ø Eurotreffer       : %.2f", statistics.averageEuroHits))
        print(String(format: "Ø EQI               : %.2f", statistics.averageEQI))

        print("")
        print("Beste Haupttreffer  : \(statistics.bestHits)")
        print("Beste Eurotreffer   : \(statistics.bestEuroHits)")

        print("")
        print("-----------------------------------")
        print("Trefferklassen")
        print("-----------------------------------")

        print("0 Richtige : \(statistics.hit0)")
        print("1 Richtige : \(statistics.hit1)")
        print("2 Richtige : \(statistics.hit2)")
        print("3 Richtige : \(statistics.hit3)")
        print("4 Richtige : \(statistics.hit4)")
        print("5 Richtige : \(statistics.hit5)")

        print("")
        print("-----------------------------------")
        print("Eurotrefferklassen")
        print("-----------------------------------")

        print("0 Eurozahlen : \(statistics.euroHit0)")
        print("1 Eurozahl   : \(statistics.euroHit1)")
        print("2 Eurozahlen : \(statistics.euroHit2)")

        print("")
        print("-----------------------------------")
        print("Gewinnklassen")
        print("-----------------------------------")

        for prize in prizeClasses {
            print("\(prize.prizeClass) : \(prize.count)")
        }

        print("")
        print(String(format: "Laufzeit : %.2f Sekunden", duration))
        print("===================================")

        return results

    }

    // MARK: - Private

    private func runSingleTest(
        session: BacktestSession,
        targetDraw: EuroJackpotDraw,
        candidateCount: Int,
        recommendationCount: Int
    ) -> BacktestResult {

        let candidates = session.generator.generate(
            count: candidateCount,
            draws: session.trainingDraws,
            hillClimbingIterations: AppSettings.backtestHillClimbingIterations
        )

        let best = session.optimizer.bestTickets(
            from: candidates,
            draws: session.trainingDraws,
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
