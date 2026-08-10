import Foundation

final class PortfolioEngine {

    func score(
        tickets: [Ticket]
    ) -> Double {

        guard !tickets.isEmpty else {
            return 0
        }

        var uniqueNumbers = Set<Int>()

        for ticket in tickets {
            uniqueNumbers.formUnion(ticket.numbers)
        }

        // Maximal können 50 verschiedene Hauptzahlen vorkommen.
        return Double(uniqueNumbers.count) / 50.0 * 100.0

    }

}
