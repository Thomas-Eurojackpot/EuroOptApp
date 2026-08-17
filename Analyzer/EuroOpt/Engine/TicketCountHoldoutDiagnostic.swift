import Foundation

struct TicketCountHoldoutDiagnostic {

    func run(
        draws: [EuroJackpotDraw]
    ) {
        guard draws.count > 140 else {
            print("❌ Ticket-Count-Holdout: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let candidateCount = max(AppSettings.backtestCandidateCount + 1, 301)
        let firstIndex = 100

        let generator = TicketGenerator()
        let optimizer = OptimizerEngine()

        var hits9 = 0
        var euroHits9 = 0
        var tickets9 = 0

        var hits10 = 0
        var euroHits10 = 0
        var tickets10 = 0

        print("")
        print("===================================")
        print("🔬 ALPHA 7.6 TICKET-COUNT HOLDOUT")
        print("===================================")
        print("Kandidaten je Test : \(candidateCount)")
        print("Vergleich           : 9 vs. 10 Tickets")
        print("Basis-Pool          : 36")
        print("")

        for index in firstIndex..<draws.count {
            let trainingDraws = Array(draws.prefix(index))
            let targetDraw = draws[index]

            let candidates = generator.generate(
                count: candidateCount,
                draws: trainingDraws,
                goal: OptimizationGoal(),
                hillClimbingIterations: 0
            )

            let ranked = optimizer.rankedTicketsForDiagnostic(
                from: candidates,
                draws: trainingDraws
            )

            let pool = Array(ranked.prefix(min(36, ranked.count)))

            let selected9 = select(
                pool: pool,
                limit: 9
            )

            let selected10 = select(
                pool: pool,
                limit: 10
            )

            for ticket in selected9 {
                hits9 += Set(ticket.numbers)
                    .intersection(targetDraw.numbers).count

                euroHits9 += Set(ticket.euroNumbers)
                    .intersection(targetDraw.euroNumbers).count
            }

            tickets9 += selected9.count

            for ticket in selected10 {
                hits10 += Set(ticket.numbers)
                    .intersection(targetDraw.numbers).count

                euroHits10 += Set(ticket.euroNumbers)
                    .intersection(targetDraw.euroNumbers).count
            }

            tickets10 += selected10.count
        }

        let main9 = Double(hits9) / Double(max(1, tickets9))
        let euro9 = Double(euroHits9) / Double(max(1, tickets9))

        let main10 = Double(hits10) / Double(max(1, tickets10))
        let euro10 = Double(euroHits10) / Double(max(1, tickets10))

        print("-----------------------------------")
        print("ALPHA 7.6 – 9 TICKETS")
        print("-----------------------------------")
        print(String(format: "Ø Haupttreffer      : %.3f", main9))
        print(String(format: "Ø Eurotreffer       : %.3f", euro9))

        print("-----------------------------------")
        print("ALPHA 7.6 – 10 TICKETS")
        print("-----------------------------------")
        print(String(format: "Ø Haupttreffer      : %.3f", main10))
        print(String(format: "Ø Eurotreffer       : %.3f", euro10))

        print("-----------------------------------")
        print("10 vs. 9 Tickets")
        print(String(format: "Δ Haupttreffer      : %+.3f", main10 - main9))
        print(String(format: "Δ Eurotreffer       : %+.3f", euro10 - euro9))
        print(String(format:
            "Kombiniertes Δ      : %+.3f",
            (main10 - main9) + (euro10 - euro9)
        ))

        print(String(format:
            "⏱ Ticket-Count: %.2f Sekunden",
            Date().timeIntervalSince(start)
        ))
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
