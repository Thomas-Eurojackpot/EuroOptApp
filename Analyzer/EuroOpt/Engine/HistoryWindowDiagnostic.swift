import Foundation

struct HistoryWindowDiagnostic {

    private let windows: [(name: String, size: Int?)] = [
        ("FULL", nil),
        ("W300", 300),
        ("W200", 200),
        ("W150", 150),
        ("W100", 100)
    ]

    func run(
        draws: [EuroJackpotDraw],
        recommendationCount: Int
    ) {
        guard draws.count > 200 else {
            print("❌ History-Window-Test: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let candidateCount = max(AppSettings.backtestCandidateCount + 1, 301)
        let holdoutSize = 100
        let holdoutStart = max(100, draws.count - holdoutSize)

        let generator = TicketGenerator()

        var results: [(name: String, main: Double, euro: Double)] = []

        print("")
        print("===================================")
        print("🔬 ALPHA 7.6 HISTORY-WINDOW TEST")
        print("===================================")
        print("Gesamte Ziehungen   : \(draws.count)")
        print("Holdout             : letzte \(draws.count - holdoutStart) Ziehungen")
        print("Kandidaten je Test  : \(candidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("")

        for window in windows {

            var totalMain = 0
            var totalEuro = 0
            var totalTickets = 0

            for index in holdoutStart..<draws.count {

                let targetDraw = draws[index]

                let availableTraining = Array(draws.prefix(index))

                let trainingDraws: [EuroJackpotDraw]

                if let size = window.size {
                    trainingDraws = Array(
                        availableTraining.suffix(min(size, availableTraining.count))
                    )
                } else {
                    trainingDraws = availableTraining
                }

                let candidates = generator.generate(
                    count: candidateCount,
                    draws: trainingDraws,
                    goal: OptimizationGoal(),
                    hillClimbingIterations: 0
                )

                let rankingEngine = OptimizerEngine()

                let ranked = rankingEngine.rankedTicketsForDiagnostic(
                    from: candidates,
                    draws: trainingDraws
                )

                let pool = Array(
                    ranked.prefix(min(36, ranked.count))
                )

                let selected = select(
                    pool: pool,
                    limit: recommendationCount
                )

                for ticket in selected {
                    totalMain += Set(ticket.numbers)
                        .intersection(targetDraw.numbers)
                        .count

                    totalEuro += Set(ticket.euroNumbers)
                        .intersection(targetDraw.euroNumbers)
                        .count
                }

                totalTickets += selected.count
            }

            let mainAverage = totalTickets > 0
                ? Double(totalMain) / Double(totalTickets)
                : 0

            let euroAverage = totalTickets > 0
                ? Double(totalEuro) / Double(totalTickets)
                : 0

            results.append(
                (
                    name: window.name,
                    main: mainAverage,
                    euro: euroAverage
                )
            )

            print(
                String(
                    format: "%@  Haupt %.3f  Euro %.3f",
                    window.name,
                    mainAverage,
                    euroAverage
                )
            )
        }

        guard let best = results.max(
            by: {
                ($0.main - 0.50) + ($0.euro - 0.333333)
                <
                ($1.main - 0.50) + ($1.euro - 0.333333)
            }
        ) else {
            print("❌ Keine verwertbaren Ergebnisse")
            return
        }

        print("")
        print("-----------------------------------")
        print("BESTES HISTORY-FENSTER")
        print("-----------------------------------")
        print("Fenster              : \(best.name)")
        print(String(format: "Ø Haupttreffer       : %.3f", best.main))
        print(String(format: "Ø Eurotreffer        : %.3f", best.euro))

        print("")
        print("Δ GEGENÜBER FULL")
        print("-----------------------------------")

        if let full = results.first(where: { $0.name == "FULL" }) {
            print(
                String(
                    format: "Haupt                : %+.3f",
                    best.main - full.main
                )
            )
            print(
                String(
                    format: "Euro                 : %+.3f",
                    best.euro - full.euro
                )
            )
            print(
                String(
                    format: "Kombiniert           : %+.3f",
                    (best.main - full.main)
                        + (best.euro - full.euro)
                )
            )
        }

        print(
            String(
                format: "⏱ History-Window: %.2f Sekunden",
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
}
