import Foundation

/// Die acht echten Quicktipp-Spielfelder aus dem unabhängigen Kontrolltest.
/// Die Zahlen werden nicht optimiert, gewichtet oder nachträglich verändert.
struct QuicktippBenchmark {

    static let tickets: [Ticket] = [
        Ticket(numbers: [9, 18, 23, 27, 42], euroNumbers: [1, 12]),
        Ticket(numbers: [3, 18, 23, 31, 48], euroNumbers: [4, 8]),
        Ticket(numbers: [7, 12, 17, 21, 30], euroNumbers: [4, 10]),
        Ticket(numbers: [15, 27, 29, 34, 43], euroNumbers: [4, 6]),
        Ticket(numbers: [7, 15, 19, 20, 33], euroNumbers: [5, 9]),
        Ticket(numbers: [26, 34, 41, 42, 48], euroNumbers: [5, 10]),
        Ticket(numbers: [4, 7, 23, 33, 42], euroNumbers: [3, 6]),
        Ticket(numbers: [13, 22, 23, 29, 35], euroNumbers: [3, 11])
    ]

    struct Summary {
        let drawCount: Int
        let ticketCount: Int
        let averageMainHitRate: Double
        let averageEuroHitRate: Double
        let combinedHitRate: Double
    }

    /// Bewertet exakt dieselben Holdout-Ziehungen wie der vorhandene Benchmark.
    /// Pro Ziehung wird zuerst über die acht Quicktipp-Felder gemittelt; dadurch
    /// kann der Vergleich später auf Ziehungsebene gepaart erfolgen.
    static func evaluate(holdout: [EuroJackpotDraw]) -> Summary {
        guard !holdout.isEmpty else {
            return Summary(
                drawCount: 0,
                ticketCount: tickets.count,
                averageMainHitRate: 0,
                averageEuroHitRate: 0,
                combinedHitRate: 0
            )
        }

        var mainRateSum = 0.0
        var euroRateSum = 0.0

        for draw in holdout {
            var drawMainRate = 0.0
            var drawEuroRate = 0.0

            for ticket in tickets {
                let mainHits = Set(ticket.numbers).intersection(draw.numbers).count
                let euroHits = Set(ticket.euroNumbers).intersection(draw.euroNumbers).count

                drawMainRate += Double(mainHits) / 5.0
                drawEuroRate += Double(euroHits) / 2.0
            }

            mainRateSum += drawMainRate / Double(tickets.count)
            euroRateSum += drawEuroRate / Double(tickets.count)
        }

        let main = mainRateSum / Double(holdout.count)
        let euro = euroRateSum / Double(holdout.count)

        return Summary(
            drawCount: holdout.count,
            ticketCount: tickets.count,
            averageMainHitRate: main,
            averageEuroHitRate: euro,
            combinedHitRate: main + euro
        )
    }
}
