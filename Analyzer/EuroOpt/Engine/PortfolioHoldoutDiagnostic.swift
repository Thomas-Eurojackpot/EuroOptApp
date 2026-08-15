import Foundation

struct PortfolioHoldoutDiagnostic {

    func run(
        candidates: [Ticket],
        ranked: [(index: Int, score: Double)],
        targetDraw: EuroJackpotDraw,
        limit: Int = 9
    ) -> [Ticket] {
        let pool = Array(ranked.prefix(min(36, ranked.count)))
        let tickets = selectPortfolio(pool: pool, candidates: candidates, limit: limit)

        let hits = tickets.reduce(0) {
            $0 + Set($1.numbers).intersection(targetDraw.numbers).count
        }
        let euroHits = tickets.reduce(0) {
            $0 + Set($1.euroNumbers).intersection(targetDraw.euroNumbers).count
        }

        return tickets
    }

    func selectPortfolio(
        ranked: [(index: Int, score: Double)],
        candidates: [Ticket],
        limit: Int
    ) -> [Ticket] {
        let pool = Array(ranked.prefix(min(36, ranked.count)))
        return selectPortfolio(pool: pool, candidates: candidates, limit: limit)
    }

    private func selectPortfolio(
        pool: [(index: Int, score: Double)],
        candidates: [Ticket],
        limit: Int
    ) -> [Ticket] {
        guard !pool.isEmpty, limit > 0 else { return [] }

        var selected: [Ticket] = []
        var usedNumbers = Set<Int>()
        selected.reserveCapacity(limit)

        // Keep Alpha ranking dominant while rewarding genuinely new main numbers.
        // This is a portfolio-selection test only; it does not alter Alpha scores.
        for _ in 0..<limit {
            var bestIndex: Int?
            var bestObjective = -Double.infinity

            for item in pool where !selected.contains(where: { $0.numbers == candidates[item.index].numbers && $0.euroNumbers == candidates[item.index].euroNumbers }) {
                let ticket = candidates[item.index]
                let score = item.score
                let newNumbers = ticket.numbers.filter { !usedNumbers.contains($0) }.count
                let overlapPenalty = selected.reduce(0) { partial, existing in
                    partial + commonNumbers(existing, ticket)
                }

                let objective = 0.70 * score
                    + 0.30 * (Double(newNumbers) / 5.0)
                    - 0.03 * Double(overlapPenalty)

                if objective > bestObjective {
                    bestObjective = objective
                    bestIndex = item.index
                }
            }

            guard let bestIndex else { break }
            let ticket = candidates[bestIndex]
            selected.append(ticket)
            usedNumbers.formUnion(ticket.numbers)
        }

        return selected
    }

    private func commonNumbers(_ lhs: Ticket, _ rhs: Ticket) -> Int {
        Set(lhs.numbers).intersection(rhs.numbers).count
    }
}