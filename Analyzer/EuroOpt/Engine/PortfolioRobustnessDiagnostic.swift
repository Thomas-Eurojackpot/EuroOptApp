import Foundation

struct PortfolioRobustnessDiagnostic {

    func run(
        draws: [EuroJackpotDraw],
        recommendationCount: Int
    ) {
        guard draws.count > 140 else {
            print("❌ Portfolio-Robustheit: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let candidateCount = max(AppSettings.backtestCandidateCount + 1, 301)
        let firstIndex = 100
        let total = draws.count - firstIndex
        let splitSize = total / 5

        let generator = TicketGenerator()
        let rankingEngine = OptimizerEngine()

        print("")
        print("===================================")
        print("🔬 ALPHA 7.6 PORTFOLIO-ROBUSTHEIT")
        print("===================================")
        print("Gesamte Holdout-Ziehungen : \(total)")
        print("Splits                    : 5")
        print("Kandidaten je Test        : \(candidateCount)")
        print("Empfehlungen              : \(recommendationCount)")
        print("Basis-Pool                : 36")
        print("")

        var totalOriginalHits = 0
        var totalOriginalEuroHits = 0
        var totalOriginalTickets = 0

        var totalPortfolioHits = 0
        var totalPortfolioEuroHits = 0
        var totalPortfolioTickets = 0

        for split in 0..<5 {
            let splitStart = firstIndex + split * splitSize
            let splitEnd = split == 4 ? draws.count : min(splitStart + splitSize, draws.count)

            var originalHits = 0
            var originalEuroHits = 0
            var originalTickets = 0

            var portfolioHits = 0
            var portfolioEuroHits = 0
            var portfolioTickets = 0

            for index in splitStart..<splitEnd {
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

                let original = selectOriginal(
                    pool: pool,
                    limit: recommendationCount
                )

                let portfolio = selectPortfolio(
                    pool: pool,
                    limit: recommendationCount
                )

                for ticket in original {
                    originalHits += Set(ticket.numbers)
                        .intersection(targetDraw.numbers).count

                    originalEuroHits += Set(ticket.euroNumbers)
                        .intersection(targetDraw.euroNumbers).count
                }

                originalTickets += original.count

                for ticket in portfolio {
                    portfolioHits += Set(ticket.numbers)
                        .intersection(targetDraw.numbers).count

                    portfolioEuroHits += Set(ticket.euroNumbers)
                        .intersection(targetDraw.euroNumbers).count
                }

                portfolioTickets += portfolio.count
            }

            totalOriginalHits += originalHits
            totalOriginalEuroHits += originalEuroHits
            totalOriginalTickets += originalTickets

            totalPortfolioHits += portfolioHits
            totalPortfolioEuroHits += portfolioEuroHits
            totalPortfolioTickets += portfolioTickets

            let originalMain = Double(originalHits) / Double(max(1, originalTickets))
            let originalEuro = Double(originalEuroHits) / Double(max(1, originalTickets))
            let portfolioMain = Double(portfolioHits) / Double(max(1, portfolioTickets))
            let portfolioEuro = Double(portfolioEuroHits) / Double(max(1, portfolioTickets))

            print(String(format:
                "Split %d  Original %.3f / %.3f   Portfolio %.3f / %.3f   Δ %+.3f / %+.3f",
                split + 1,
                originalMain,
                originalEuro,
                portfolioMain,
                portfolioEuro,
                portfolioMain - originalMain,
                portfolioEuro - originalEuro
            ))
        }

        let originalMain = Double(totalOriginalHits) / Double(max(1, totalOriginalTickets))
        let originalEuro = Double(totalOriginalEuroHits) / Double(max(1, totalOriginalTickets))
        let portfolioMain = Double(totalPortfolioHits) / Double(max(1, totalPortfolioTickets))
        let portfolioEuro = Double(totalPortfolioEuroHits) / Double(max(1, totalPortfolioTickets))

        print("")
        print("-----------------------------------")
        print("GESAMTERGEBNIS")
        print("-----------------------------------")
        print(String(format: "Original Haupt       : %.3f", originalMain))
        print(String(format: "Portfolio Haupt      : %.3f", portfolioMain))
        print(String(format: "Δ Haupt              : %+.3f", portfolioMain - originalMain))
        print("")
        print(String(format: "Original Euro        : %.3f", originalEuro))
        print(String(format: "Portfolio Euro       : %.3f", portfolioEuro))
        print(String(format: "Δ Euro               : %+.3f", portfolioEuro - originalEuro))
        print("")
        print(String(format:
            "Kombiniertes Δ       : %+.3f",
            (portfolioMain - originalMain) +
            (portfolioEuro - originalEuro)
        ))
        print(String(format:
            "⏱ Portfolio-Robustheit: %.2f Sekunden",
            Date().timeIntervalSince(start)
        ))
        print("===================================")
    }

    private func selectOriginal(
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

                guard !selected.contains(where: {
                    $0.numbers == ticket.numbers &&
                    $0.euroNumbers == ticket.euroNumbers
                }) else {
                    continue
                }

                let newNumbers = ticket.numbers.filter {
                    !usedNumbers.contains($0)
                }.count

                let overlapPenalty = selected.reduce(0) {
                    $0 + commonNumbers($1, ticket)
                }

                let objective =
                    0.70 * item.score +
                    0.30 * (Double(newNumbers) / 5.0) -
                    0.03 * Double(overlapPenalty)

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

    private func commonNumbers(
        _ lhs: Ticket,
        _ rhs: Ticket
    ) -> Int {
        Set(lhs.numbers)
            .intersection(rhs.numbers)
            .count
    }
}
