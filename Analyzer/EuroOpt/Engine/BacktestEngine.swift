//
//  BacktestEngine.swift
//  EuroOpt
//
//  Alpha 7.4 - Performance
//

import Foundation

final class BacktestEngine {

    func run(
        draws: [EuroJackpotDraw],
        candidateCount: Int,
        recommendationCount: Int,
        goal: OptimizationGoal = OptimizationGoal(),
        progress: @escaping (_ progress: Double, _ current: Int, _ total: Int) -> Void
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
                recommendationCount: recommendationCount,
                goal: goal
            )

            results.append(result)
            session.add(draw: targetDraw)

            let current = index - 99
            progress(Double(current) / Double(totalTests), current, totalTests)
        }

        let statistics = BacktestStatistics.calculate(from: results)
        let prizeClasses = PrizeClassCalculator.calculate(from: results)
        let duration = Date().timeIntervalSince(start)

        print("")
        print("===================================")
        print("📊 ALPHA 7.4 AUSWERTUNG")
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
        print(String(format: "Laufzeit Alpha 7.4 : %.2f Sekunden", duration))

        // Fair baseline: same historical target draws and exactly the same
        // number of tickets per draw, but generated without using the model.
        let baselineStart = Date()
        let baselineResults = runRandomBaseline(
            draws: draws,
            recommendationCount: recommendationCount
        )
        let baselineStatistics = BacktestStatistics.calculate(from: baselineResults)
        let baselinePrizeClasses = PrizeClassCalculator.calculate(from: baselineResults)
        let baselineDuration = Date().timeIntervalSince(baselineStart)

        print("")
        print("===================================")
        print("🎲 ZUFALLS-BASISLINIE")
        print("===================================")
        print("Gleiche Ziehungen    : \(baselineStatistics.totalTests)")
        print("Tickets je Ziehung   : \(recommendationCount)")
        print(String(format: "Ø Haupttreffer       : %.2f", baselineStatistics.averageHits))
        print(String(format: "Ø Eurotreffer        : %.2f", baselineStatistics.averageEuroHits))
        print("")
        print("Beste Haupttreffer   : \(baselineStatistics.bestHits)")
        print("Beste Eurotreffer    : \(baselineStatistics.bestEuroHits)")
        print("")
        print("Trefferklassen")
        print("0 Richtige : \(baselineStatistics.hit0)")
        print("1 Richtige : \(baselineStatistics.hit1)")
        print("2 Richtige : \(baselineStatistics.hit2)")
        print("3 Richtige : \(baselineStatistics.hit3)")
        print("4 Richtige : \(baselineStatistics.hit4)")
        print("5 Richtige : \(baselineStatistics.hit5)")
        print("")
        print("Eurotrefferklassen")
        print("0 Eurozahlen : \(baselineStatistics.euroHit0)")
        print("1 Eurozahl   : \(baselineStatistics.euroHit1)")
        print("2 Eurozahlen : \(baselineStatistics.euroHit2)")
        print("")
        print("Gewinnklassen")
        for prize in baselinePrizeClasses {
            print("\(prize.prizeClass) : \(prize.count)")
        }

        let alphaAverageHits = statistics.averageHits
        let baselineAverageHits = baselineStatistics.averageHits
        let alphaAverageEuroHits = statistics.averageEuroHits
        let baselineAverageEuroHits = baselineStatistics.averageEuroHits

        print("")
        print("===================================")
        print("⚖️ ALPHA 7.4 vs. ZUFALL")
        print("===================================")
        print(String(format: "Ø Haupttreffer : %.2f vs %.2f", alphaAverageHits, baselineAverageHits))
        print(String(format: "Ø Eurotreffer  : %.2f vs %.2f", alphaAverageEuroHits, baselineAverageEuroHits))
        print(String(format: "Mehr Haupttreffer: %+.2f", alphaAverageHits - baselineAverageHits))
        print(String(format: "Mehr Eurotreffer : %+.2f", alphaAverageEuroHits - baselineAverageEuroHits))
        print("")
        print(String(format: "Laufzeit Zufall  : %.2f Sekunden", baselineDuration))
        print("===================================")

        return results
    }

    private func runSingleTest(
        session: BacktestSession,
        targetDraw: EuroJackpotDraw,
        candidateCount: Int,
        recommendationCount: Int,
        goal: OptimizationGoal
    ) -> BacktestResult {

        let candidates = session.generator.generate(
            count: candidateCount,
            draws: session.trainingDraws,
            goal: goal,
            hillClimbingIterations: AppSettings.backtestHillClimbingIterations
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
            let hits = Set(ticket.ticket.numbers).intersection(targetDraw.numbers).count
            let euroHits = Set(ticket.ticket.euroNumbers).intersection(targetDraw.euroNumbers).count

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

    private func runRandomBaseline(
        draws: [EuroJackpotDraw],
        recommendationCount: Int
    ) -> [BacktestResult] {

        let session = SeededRandomGenerator(seed: 0xE7A7_7401)
        var results: [BacktestResult] = []

        guard draws.count > 100 else { return results }

        for index in 100..<draws.count {
            let targetDraw = draws[index]
            var ticketResults: [BacktestTicketResult] = []
            var bestHits = 0
            var bestEuroHits = 0
            var totalHits = 0
            var totalEuroHits = 0

            for rank in 1...recommendationCount {
                let ticket = session.makeTicket()
                let hits = Set(ticket.numbers).intersection(targetDraw.numbers).count
                let euroHits = Set(ticket.euroNumbers).intersection(targetDraw.euroNumbers).count

                ticketResults.append(
                    BacktestTicketResult(
                        rank: rank,
                        hits: hits,
                        euroHits: euroHits,
                        eqi: 0
                    )
                )

                bestHits = max(bestHits, hits)
                bestEuroHits = max(bestEuroHits, euroHits)
                totalHits += hits
                totalEuroHits += euroHits
            }

            results.append(
                BacktestResult(
                    drawDate: targetDraw.date,
                    recommendationCount: recommendationCount,
                    ticketResults: ticketResults,
                    bestHits: bestHits,
                    bestEuroHits: bestEuroHits,
                    averageHits: Double(totalHits) / Double(recommendationCount),
                    averageEuroHits: Double(totalEuroHits) / Double(recommendationCount),
                    averageEQI: 0,
                    testedTickets: recommendationCount
                )
            )
        }

        return results
    }
}

private final class SeededRandomGenerator {

    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    private func nextUInt64() -> UInt64 {
        // Deterministic LCG: reproducible baseline across runs.
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    private func nextInt(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(nextUInt64() % UInt64(upperBound))
    }

    func makeTicket() -> Ticket {
        var numbers = Array(1...50)
        var euroNumbers = Array(1...12)

        for index in stride(from: numbers.count - 1, through: 1, by: -1) {
            let swapIndex = nextInt(upperBound: index + 1)
            numbers.swapAt(index, swapIndex)
        }

        for index in stride(from: euroNumbers.count - 1, through: 1, by: -1) {
            let swapIndex = nextInt(upperBound: index + 1)
            euroNumbers.swapAt(index, swapIndex)
        }

        return Ticket(
            numbers: Array(numbers.prefix(5)).sorted(),
            euroNumbers: Array(euroNumbers.prefix(2)).sorted()
        )
    }
}
