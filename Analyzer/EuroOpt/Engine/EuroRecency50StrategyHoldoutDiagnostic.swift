import Foundation

final class EuroRecency50StrategyHoldoutDiagnostic {

    private let recencyWindow = 50
    private let firstIndex = 100
    private let basePoolSize = 36

    func run(
        draws: [EuroJackpotDraw],
        recommendationCount: Int
    ) {

        guard draws.count > firstIndex + recencyWindow else {
            print("❌ Alpha 7.7 Holdout: zu wenige Ziehungen.")
            return
        }

        let start = Date()

        let candidateCount =
            max(
                AppSettings.backtestCandidateCount + 1,
                301
            )

        let generator = TicketGenerator()

        var originalMainHits = 0
        var originalEuroHits = 0
        var originalTickets = 0

        var alpha77MainHits = 0
        var alpha77EuroHits = 0
        var alpha77Tickets = 0

        print("")
        print("===================================")
        print("🎯 ALPHA 7.7 – RECENCY 50 STRATEGIE-HOLDOUT")
        print("===================================")
        print("Signal             : Recency 50 / Top 2 Eurozahlen")
        print("🔒 Recency 50      : eingefroren")
        print("Ziehungsstart      : \(firstIndex)")
        print("Kandidaten je Test : \(candidateCount)")
        print("Empfehlungen       : \(recommendationCount)")
        print("Basis-Pool         : \(basePoolSize)")
        print("Holdout            : gesamte verfügbare Strecke")
        print("")

        for index in firstIndex..<draws.count {

            let trainingDraws = Array(draws.prefix(index))
            let targetDraw = draws[index]

            guard trainingDraws.count >= recencyWindow else {
                continue
            }

            let candidates = generator.generate(
                count: candidateCount,
                draws: trainingDraws,
                goal: OptimizationGoal(),
                hillClimbingIterations: 0
            )

            let ranked = ranked(
                candidates: candidates,
                draws: trainingDraws
            )

            let basePool = Array(
                ranked.prefix(
                    min(basePoolSize, ranked.count)
                )
            )

            let original = diverseTickets(
                ranked: basePool,
                candidates: candidates,
                limit: recommendationCount
            )

            let topEuroNumbers = recency50TopTwo(
                draws: trainingDraws
            )

            let alpha77 = original.map { ticket in
                Ticket(
                    numbers: ticket.numbers,
                    euroNumbers: topEuroNumbers
                )
            }

            for ticket in original {
                originalMainHits +=
                    Set(ticket.numbers)
                    .intersection(targetDraw.numbers)
                    .count

                originalEuroHits +=
                    Set(ticket.euroNumbers)
                    .intersection(targetDraw.euroNumbers)
                    .count
            }

            originalTickets += original.count

            for ticket in alpha77 {
                alpha77MainHits +=
                    Set(ticket.numbers)
                    .intersection(targetDraw.numbers)
                    .count

                alpha77EuroHits +=
                    Set(ticket.euroNumbers)
                    .intersection(targetDraw.euroNumbers)
                    .count
            }

            alpha77Tickets += alpha77.count

            let current = index - firstIndex + 1

            if current.isMultiple(of: 50) {
                print(
                    "... Holdout \(current) / \(draws.count - firstIndex)"
                )
            }
        }

        let originalMain =
            originalTickets > 0
            ? Double(originalMainHits) / Double(originalTickets)
            : 0

        let originalEuro =
            originalTickets > 0
            ? Double(originalEuroHits) / Double(originalTickets)
            : 0

        let alpha77Main =
            alpha77Tickets > 0
            ? Double(alpha77MainHits) / Double(alpha77Tickets)
            : 0

        let alpha77Euro =
            alpha77Tickets > 0
            ? Double(alpha77EuroHits) / Double(alpha77Tickets)
            : 0

        let originalCombined =
            originalMain + originalEuro

        let alpha77Combined =
            alpha77Main + alpha77Euro

        let deltaMain =
            alpha77Main - originalMain

        let deltaEuro =
            alpha77Euro - originalEuro

        let deltaCombined =
            alpha77Combined - originalCombined

        print("")
        print("-----------------------------------")
        print("ALPHA 7.6 ORIGINAL")
        print("-----------------------------------")
        print(String(format: "Ø Haupttreffer      : %.3f", originalMain))
        print(String(format: "Ø Eurotreffer       : %.3f", originalEuro))
        print(String(format: "Kombiniert          : %.3f", originalCombined))

        print("")
        print("-----------------------------------")
        print("ALPHA 7.7 + RECENCY 50")
        print("-----------------------------------")
        print(String(format: "Ø Haupttreffer      : %.3f", alpha77Main))
        print(String(format: "Ø Eurotreffer       : %.3f", alpha77Euro))
        print(String(format: "Kombiniert          : %.3f", alpha77Combined))

        print("")
        print("-----------------------------------")
        print("7.7 vs. ORIGINAL")
        print("-----------------------------------")
        print(String(format: "Δ Haupttreffer      : %+.3f", deltaMain))
        print(String(format: "Δ Eurotreffer       : %+.3f", deltaEuro))
        print(String(format: "Kombiniertes Δ      : %+.3f", deltaCombined))

        print("")
        print("Interpretation:")
        print("- Hauptzahlen bleiben unverändert.")
        print("- Ticket-Auswahl bleibt unverändert.")
        print("- Nur die Eurozahlen werden durch Recency 50 / Top 2 ersetzt.")
        print("- Recency 50 verwendet ausschließlich vorherige Ziehungen.")
        print("- Kein Testergebnis beeinflusst das Signal.")

        print("")
        print(
            String(
                format: "⏱ Alpha 7.7 Holdout: %.2f Sekunden",
                Date().timeIntervalSince(start)
            )
        )

        print("===================================")
    }

    private func recency50TopTwo(
        draws: [EuroJackpotDraw]
    ) -> [Int] {

        let start = max(
            0,
            draws.count - recencyWindow
        )

        var frequencies: [Int: Int] = [:]

        for index in start..<draws.count {
            for number in draws[index].euroNumbers {
                frequencies[number, default: 0] += 1
            }
        }

        let ranked = frequencies.keys.sorted {
            let lhs = frequencies[$0] ?? 0
            let rhs = frequencies[$1] ?? 0

            if lhs == rhs {
                return $0 < $1
            }

            return lhs > rhs
        }

        return Array(ranked.prefix(2))
    }

    private func ranked(
        candidates: [Ticket],
        draws: [EuroJackpotDraw]
    ) -> [(index: Int, score: Double)] {

        let scoreCache = ScoreCache(draws: draws)
        let scoreEngine = ScoreEngine(cache: scoreCache)

        return candidates.indices
            .map { index in
                (
                    index: index,
                    score: scoreEngine.score(
                        ticket: candidates[index]
                    )
                )
            }
            .sorted {
                $0.score > $1.score
            }
    }

    private func diverseTickets(
        ranked: [(index: Int, score: Double)],
        candidates: [Ticket],
        limit: Int
    ) -> [Ticket] {

        var result: [Ticket] = []
        result.reserveCapacity(limit)

        for item in ranked {

            let ticket = candidates[item.index]

            if result.allSatisfy({
                commonMainNumbers($0, ticket) < 3
            }) {
                result.append(ticket)
            }

            if result.count == limit {
                break
            }
        }

        return result
    }

    private func commonMainNumbers(
        _ lhs: Ticket,
        _ rhs: Ticket
    ) -> Int {

        Set(lhs.numbers)
            .intersection(rhs.numbers)
            .count
    }
}
