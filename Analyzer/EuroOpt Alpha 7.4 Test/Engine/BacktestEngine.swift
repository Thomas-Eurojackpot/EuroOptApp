//
//  BacktestEngine.swift
//  EuroOpt
//
//  Alpha 7.4 Test
//

import Foundation

final class BacktestEngine {

    // MARK: - Public

    func run(
        draws: [EuroJackpotDraw],
        candidateCount: Int,
        recommendationCount: Int,
        goal: OptimizationGoal = OptimizationGoal(),
        progress: @escaping (_ progress: Double,
                             _ current: Int,
                             _ total: Int) -> Void
    ) -> [BacktestResult] {

        guard draws.count > 50 else {
            print("❌ Zu wenige Ziehungen")
            return []
        }

        let start = Date()

        let maxTests = min(50, draws.count - 50)

        var results: [BacktestResult] = []

        print("===================================")
        print("🧪 EUROOPT BACKTEST")
        print("===================================")

        let session = BacktestSession(
            trainingDraws: Array(draws.prefix(50)),
            goal: goal
        )

        for index in 50..<(50 + maxTests) {

            let targetDraw = draws[index]

            PerformanceTimer.shared.start("Single Backtest")

            let result = runSingleTest(
                session: session,
                targetDraw: targetDraw,
                candidateCount: candidateCount,
                recommendationCount: recommendationCount,
                goal: goal
            )

            PerformanceTimer.shared.stop("Single Backtest")

            results.append(result)

            session.add(draw: targetDraw)

            let current = index - 49

            progress(
                Double(current) / Double(maxTests),
                current,
                maxTests
            )

        }

        let statistics = BacktestStatistics.calculate(
            from: results
        )

        let prizeClasses = statistics.prizeClasses

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
        print("Gewinnklassen")
        print("-----------------------------------")

        for prize in prizeClasses {
            print("\(prize.prizeClass) : \(prize.count)")
        }

        // -------------------------------------------------------------
        // Unabhängiger Quicktipp-Kontrolltest
        // -------------------------------------------------------------
        // Exakt derselbe Holdout wie im Backtest: dieselben 50 Zielziehungen.
        // Die acht real gespielten Quicktipp-Felder werden weder optimiert
        // noch aus historischen Treffern ausgewählt.
        let holdout = Array(draws[50..<(50 + maxTests)])

        if let comparison = QuicktippBenchmark.compare(
            modelResults: results,
            holdout: holdout
        ) {
            print("")
            print("===================================")
            print("🎟 QUICKTIPP – HOLDOUT-KONTROLLTEST")
            print("===================================")
            print("Spielfelder          : 8")
            print("Gleicher Holdout     : JA")
            print("Gepaarter Vergleich  : JA")
            print("95-%-KI              : t-Verteilung, df = 49")
            print("")
            print(String(format: "Ø Modell Haupt      : %.4f", comparison.modelMain))
            print(String(format: "Ø Quicktipp Haupt   : %.4f", comparison.quicktippMain))
            print(String(format: "Δ Modell - Quicktipp: %+0.4f", comparison.deltaMain))
            print(String(format: "95%% CI Δ Haupt      : ±%.4f", comparison.ci95Main))
            print("")
            print(String(format: "Ø Modell Euro       : %.4f", comparison.modelEuro))
            print(String(format: "Ø Quicktipp Euro    : %.4f", comparison.quicktippEuro))
            print(String(format: "Δ Modell - Quicktipp: %+0.4f", comparison.deltaEuro))
            print(String(format: "95%% CI Δ Euro      : ±%.4f", comparison.ci95Euro))
            print("")
            print(String(format: "Δ kombiniert        : %+0.4f", comparison.deltaCombined))
            print(String(format: "95%% CI Δ kombiniert : ±%.4f", comparison.ci95Combined))
            print("")
            print("Interpretation:")
            print("- Die acht Quicktipp-Felder wurden unverändert als unabhängige Kontrollgruppe verwendet.")
            print("- Modell und Quicktipp wurden auf exakt denselben Holdout-Ziehungen gepaart.")
            print("- Der Holdout wurde nicht zur Auswahl oder Veränderung der Quicktipps verwendet.")
            print("- Das KI basiert auf den Ziehungsebene-Differenzen und dem t-Wert für df = 49.")
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
        recommendationCount: Int,
        goal: OptimizationGoal
    ) -> BacktestResult {

        PerformanceTimer.shared.start("TicketGenerator")

        let candidates = session.generator.generate(
            count: candidateCount,
            draws: session.trainingDraws,
            hillClimbingIterations: AppSettings.backtestHillClimbingIterations
        )

        PerformanceTimer.shared.stop("TicketGenerator")

        PerformanceTimer.shared.start("Optimizer")

        let best = session.optimizer.bestTickets(
            from: candidates,
            draws: session.trainingDraws,
            goal: goal,
            limit: recommendationCount
        )

        PerformanceTimer.shared.stop("Optimizer")

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
