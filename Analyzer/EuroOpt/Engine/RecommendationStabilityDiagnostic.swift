import Foundation

struct RecommendationStabilityDiagnostic {

    func run(
        draws: [EuroJackpotDraw],
        recommendationCount: Int,
        runCount: Int = 10
    ) {
        guard !draws.isEmpty else {
            print("❌ Stabilitätstest: keine Ziehungen vorhanden")
            return
        }

        let start = Date()
        let candidateCount = max(
            AppSettings.backtestCandidateCount + 1,
            301
        )

        print("")
        print("===================================")
        print("🔬 ALPHA 7.6 EMPFEHLUNGS-STABILITÄT")
        print("===================================")
        print("Unabhängige Läufe   : \(runCount)")
        print("Kandidaten je Lauf  : \(candidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("Historie            : \(draws.count) Ziehungen")
        print("")

        var allRuns: [[Ticket]] = []

        for run in 1...runCount {

            let generator = TicketGenerator()

            let candidates = generator.generate(
                count: candidateCount,
                draws: draws,
                goal: OptimizationGoal(),
                hillClimbingIterations: AppSettings.hillClimbingIterations
            )

            let ranked = OptimizerEngine()
                .rankedTicketsForDiagnostic(
                    from: candidates,
                    draws: draws
                )

            let pool = Array(
                ranked.prefix(min(36, ranked.count))
            )

            let selected = select(
                pool: pool,
                limit: recommendationCount
            )

            allRuns.append(selected)

            print(
                "Lauf \(run): \(selected.count) Empfehlungen"
            )
        }

        guard allRuns.count >= 2 else {
            print("❌ Zu wenige Läufe für Vergleich")
            return
        }

        // ---------------------------------------------------------
        // Exakte Wiederholungen
        // ---------------------------------------------------------

        var ticketFrequency: [
            String: Int
        ] = [:]

        for run in allRuns {
            for ticket in run {
                let key =
                    ticket.numbers
                        .map(String.init)
                        .joined(separator: ",")
                    + "|"
                    + ticket.euroNumbers
                        .map(String.init)
                        .joined(separator: ",")

                ticketFrequency[key, default: 0] += 1
            }
        }

        let repeatedTickets =
            ticketFrequency.values
                .filter { $0 > 1 }
                .count

        let maximumRepeat =
            ticketFrequency.values.max() ?? 0

        // ---------------------------------------------------------
        // Paarweise Ähnlichkeit der Empfehlungen
        // ---------------------------------------------------------

        var mainSimilarityTotal = 0.0
        var euroSimilarityTotal = 0.0
        var comparisons = 0

        for i in 0..<allRuns.count {
            for j in (i + 1)..<allRuns.count {

                let lhs = allRuns[i]
                let rhs = allRuns[j]

                for ticket in lhs {

                    let bestMain = rhs.map {
                        commonNumbers(ticket, $0)
                    }.max() ?? 0

                    let bestEuro = rhs.map {
                        commonEuroNumbers(ticket, $0)
                    }.max() ?? 0

                    mainSimilarityTotal += Double(bestMain)
                    euroSimilarityTotal += Double(bestEuro)
                    comparisons += 1
                }
            }
        }

        let averageMainSimilarity =
            comparisons > 0
                ? mainSimilarityTotal / Double(comparisons)
                : 0

        let averageEuroSimilarity =
            comparisons > 0
                ? euroSimilarityTotal / Double(comparisons)
                : 0

        // ---------------------------------------------------------
        // Häufigste Hauptzahlen
        // ---------------------------------------------------------

        var numberFrequency: [
            Int: Int
        ] = [:]

        for run in allRuns {
            for ticket in run {
                for number in ticket.numbers {
                    numberFrequency[number, default: 0] += 1
                }
            }
        }

        let topNumbers = numberFrequency
            .sorted {
                if $0.value == $1.value {
                    return $0.key < $1.key
                }

                return $0.value > $1.value
            }
            .prefix(10)

        // ---------------------------------------------------------
        // Ergebnis
        // ---------------------------------------------------------

        print("")
        print("-----------------------------------")
        print("STABILITÄTSERGEBNIS")
        print("-----------------------------------")

        print(
            "Exakt wiederholte Tickets : \(repeatedTickets)"
        )

        print(
            "Max. Wiederholung eines Tickets : \(maximumRepeat)x"
        )

        print(
            String(
                format:
                    "Ø beste Hauptzahl-Überschneidung : %.3f",
                averageMainSimilarity
            )
        )

        print(
            String(
                format:
                    "Ø beste Eurozahl-Überschneidung  : %.3f",
                averageEuroSimilarity
            )
        )

        print("")
        print("Häufigste Hauptzahlen über alle Läufe:")
        print(
            topNumbers
                .map {
                    "\($0.key): \($0.value)x"
                }
                .joined(separator: " | ")
        )

        print("")
        print("===================================")
        print(
            String(
                format:
                    "⏱ Empfehlungs-Stabilität: %.2f Sekunden",
                Date().timeIntervalSince(start)
            )
        )
        print("===================================")
    }

    private func select(
        pool: [(ticket: Ticket, score: Double)],
        limit: Int
    ) -> [Ticket] {

        var selected: [Ticket] = []

        for item in pool {

            if selected.allSatisfy({
                commonNumbers($0, item.ticket) < 3
            }) {
                selected.append(item.ticket)
            }

            if selected.count == limit {
                break
            }
        }

        return selected
    }

    private func commonNumbers(
        _ lhs: Ticket,
        _ rhs: Ticket
    ) -> Int {

        Set(lhs.numbers)
            .intersection(rhs.numbers)
            .count
    }

    private func commonEuroNumbers(
        _ lhs: Ticket,
        _ rhs: Ticket
    ) -> Int {

        Set(lhs.euroNumbers)
            .intersection(rhs.euroNumbers)
            .count
    }
}
