import Foundation

final class PortfolioEngine {

    func score(
        tickets: [Ticket]
    ) -> Double {

        guard !tickets.isEmpty else {
            return 0
        }

        // Unterschiedliche Hauptzahlen
        var uniqueMain = Set<Int>()

        // Unterschiedliche Eurozahlen
        var uniqueEuro = Set<Int>()

        for ticket in tickets {
            uniqueMain.formUnion(ticket.numbers)
            uniqueEuro.formUnion(ticket.euroNumbers)
        }

        let mainScore = Double(uniqueMain.count) / 50.0 * 70.0
        let euroScore = Double(uniqueEuro.count) / 12.0 * 10.0

        // Überschneidungen bestrafen
        var overlapPenalty = 0.0

        if tickets.count > 1 {
            for i in 0..<(tickets.count - 1) {
                for j in (i + 1)..<tickets.count {

                    let overlap = Set(tickets[i].numbers)
                        .intersection(tickets[j].numbers)
                        .count

                    if overlap >= 4 {
                        overlapPenalty += Double(overlap - 3) * 2.0
                    }
                }
            }
        }

        let diversityScore = max(
            0,
            20.0 - overlapPenalty
        )

        return mainScore + euroScore + diversityScore
    }
}
