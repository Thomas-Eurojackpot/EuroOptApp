import Foundation

struct PortfolioHoldoutDiagnostic {

    func run(
        draws: [EuroJackpotDraw],
        recommendationCount: Int
    ) {
        guard draws.count > 140 else { return }

        let start = Date()
        let candidateCount = max(AppSettings.backtestCandidateCount + 1, 301)
        let firstIndex = 100
        let generator = TicketGenerator()
        let rankingEngine = OptimizerEngine()

        var originalHits = 0
        var originalEuroHits = 0
        var originalTickets = 0
        var portfolioHits = 0
        var portfolioEuroHits = 0
        var portfolioTickets = 0

        print("")
        print("===================================")
        print("🧪 ALPHA 7.6 PORTFOLIO HOLDOUT")
        print("===================================")
        print("Ziehungen           : \(draws.count - firstIndex)")
        print("Kandidaten je Test  : \(candidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("Basis-Pool          : 36")
        print("Portfolio-Auswahl   : Score + neue Hauptzahlen")
        print("🔒 Portfolio-Regel wird nur zur Ticket-Auswahl verwendet.")
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

            let ranked = rankingEngine.rankedTicketsForDiagnostic(
                from: candidates,
                draws: trainingDraws
            )
            let pool = Array(ranked.prefix(min(36, ranked.count)))

            let original = selectOriginal(pool: pool, limit: recommendationCount)
            let portfolio = selectPortfolio(pool: pool, limit: recommendationCount)

            for ticket in original {
                originalHits += Set(ticket.numbers).intersection(targetDraw.numbers).count
                originalEuroHits += Set(ticket.euroNumbers).intersection(targetDraw.euroNumbers).count
            }
            originalTickets += original.count

            for ticket in portfolio {
                portfolioHits += Set(ticket.numbers).intersection(targetDraw.numbers).count
                portfolioEuroHits += Set(ticket.euroNumbers).intersection(targetDraw.euroNumbers).count
            }
            portfolioTickets += portfolio.count

            let current = index - firstIndex + 1
            if current.isMultiple(of: 50) {
                print("... Holdout \(current) / \(draws.count - firstIndex)")
            }
        }

        let originalMain = originalTickets > 0 ? Double(originalHits) / Double(originalTickets) : 0
        let originalEuro = originalTickets > 0 ? Double(originalEuroHits) / Double(originalTickets) : 0
        let portfolioMain = portfolioTickets > 0 ? Double(portfolioHits) / Double(portfolioTickets) : 0
        let portfolioEuro = portfolioTickets > 0 ? Double(portfolioEuroHits) / Double(portfolioTickets) : 0

        print("")
        print("-----------------------------------")
        print("ALPHA 7.6 ORIGINAL")
        print("-----------------------------------")
        print(String(format: "Ø Haupttreffer      : %.3f", originalMain))
        print(String(format: "Ø Eurotreffer       : %.3f", originalEuro))
        print("-----------------------------------")
        print("ALPHA 7.6 + PORTFOLIO")
        print("-----------------------------------")
        print(String(format: "Ø Haupttreffer      : %.3f", portfolioMain))
        print(String(format: "Ø Eurotreffer       : %.3f", portfolioEuro))
        print("-----------------------------------")
        print("Portfolio vs. Original")
        print(String(format: "Δ Haupttreffer      : %+.3f", portfolioMain - originalMain))
        print(String(format: "Δ Eurotreffer       : %+.3f", portfolioEuro - originalEuro))
        print(String(format: "Kombiniertes Δ      : %+.3f", (portfolioMain - originalMain) + (portfolioEuro - originalEuro)))
        print(String(format: "⏱ Portfolio-Holdout: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func selectOriginal(
        pool: [(ticket: Ticket, score: Double)],
        limit: Int
    ) -> [Ticket] {
        var selected: [Ticket] = []
        for item in pool {
            if selected.allSatisfy({ commonNumbers($0, item.ticket) < 3 }) {
                selected.append(item.ticket)
            }
            if selected.count == limit { break }
        }
        return selected
    }

    private func selectPortfolio(
        pool: [(ticket: Ticket, score: Double)],
        limit: Int
    ) -> [Ticket] {
        guard !pool.isEmpty, limit > 0 else { return [] }

        var selected: [Ticket] = []
        var usedNumbers = Set<Int>()
        selected.reserveCapacity(limit)

        for _ in 0..<limit {
            var bestPosition: Int?
            var bestObjective = -Double.infinity

            for position in pool.indices {
                let item = pool[position]
                let ticket = item.ticket
                guard !selected.contains(where: { $0.numbers == ticket.numbers && $0.euroNumbers == ticket.euroNumbers }) else { continue }

                let newNumbers = ticket.numbers.filter { !usedNumbers.contains($0) }.count
                let overlapPenalty = selected.reduce(0) { partial, existing in
                    partial + commonNumbers(existing, ticket)
                }

                let objective = 0.70 * item.score
                    + 0.30 * (Double(newNumbers) / 5.0)
                    - 0.03 * Double(overlapPenalty)

                if objective > bestObjective {
                    bestObjective = objective
                    bestPosition = position
                }
            }

            guard let bestPosition else { break }
            let ticket = pool[bestPosition].ticket
            selected.append(ticket)
            usedNumbers.formUnion(ticket.numbers)
        }

        return selected
    }

    private func commonNumbers(_ lhs: Ticket, _ rhs: Ticket) -> Int {
        Set(lhs.numbers).intersection(rhs.numbers).count
    }
}
