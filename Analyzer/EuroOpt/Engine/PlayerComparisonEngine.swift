import Foundation

final class PlayerComparisonEngine {

    struct Player {
        let name: String
        let tickets: [Ticket]
    }

    struct Result {
        let player: String
        let tickets: Int
        let draws: Int
        let mainHits: Int
        let euroHits: Int
        let expectedMainHits: Double
        let expectedEuroHits: Double
        let classes: [String: Int]
    }

    func compare(draws: [EuroJackpotDraw], players: [Player], holdoutDraws: Int = 50) -> [Result] {
        guard draws.count > 100 + holdoutDraws else { return [] }
        let start = draws.count - holdoutDraws
        let targets = Array(draws[start..<draws.count])

        return players.map { player in
            var mainHits = 0
            var euroHits = 0
            var expectedMain = 0.0
            var expectedEuro = 0.0
            var classes: [String: Int] = [:]

            for target in targets {
                for ticket in player.tickets {
                    let mh = Set(ticket.numbers).intersection(target.numbers).count
                    let eh = Set(ticket.euroNumbers).intersection(target.euroNumbers).count
                    mainHits += mh
                    euroHits += eh
                    let key = "\(mh)-\(eh)"
                    classes[key, default: 0] += 1
                }
                expectedMain += Double(player.tickets.count) * 0.5
                let euroCount = target.date < Self.euroFormatCutoverDate ? 10 : 12
                expectedEuro += Double(player.tickets.count) * (2.0 / Double(euroCount))
            }

            return Result(
                player: player.name,
                tickets: player.tickets.count,
                draws: targets.count,
                mainHits: mainHits,
                euroHits: euroHits,
                expectedMainHits: expectedMain,
                expectedEuroHits: expectedEuro,
                classes: classes
            )
        }
    }

    private static let euroFormatCutoverDate: Date = {
        var c = DateComponents()
        c.year = 2022; c.month = 3; c.day = 25
        return Calendar(identifier: .gregorian).date(from: c)!
    }()
}
