import Foundation

struct NineTipComparisonResult {
    struct PlayerResult {
        let name: String
        let classes: [Int]
        let total: Int
        let percentages: [Double]
        let mainAverage: Double
        let euroAverage: Double
    }

    let holdoutDraws: Int
    let alphaProfileID: Int
    let players: [PlayerResult]

    static let classLabels: [String] = {
        var result: [String] = []
        for main in 0...5 {
            for euro in 0...2 {
                result.append("\(main)-\(euro)")
            }
        }
        return result
    }()
}

final class NineTipComparisonEngine {
    private let holdoutCount = 50
    private let warmup = WeightSweepCore.warmup
    private let f2Window = 50
    private let recommendationCount = 9

    private let ralfTickets: [Ticket] = [
        Ticket(numbers: [9, 12, 29, 32, 41], euroNumbers: [2, 8]),
        Ticket(numbers: [2, 7, 11, 15, 23], euroNumbers: [4, 10]),
        Ticket(numbers: [2, 5, 13, 27, 29], euroNumbers: [2, 10]),
        Ticket(numbers: [10, 18, 44, 47, 50], euroNumbers: [4, 10]),
        Ticket(numbers: [2, 15, 29, 42, 49], euroNumbers: [2, 11]),
        Ticket(numbers: [11, 13, 32, 35, 41], euroNumbers: [2, 10]),
        Ticket(numbers: [18, 22, 33, 40, 45], euroNumbers: [9, 10]),
        Ticket(numbers: [21, 31, 32, 35, 49], euroNumbers: [7, 10]),
        Ticket(numbers: [19, 32, 33, 35, 42], euroNumbers: [2, 9])
    ]

    func run(draws: [EuroJackpotDraw]) -> NineTipComparisonResult? {
        guard draws.count > warmup + holdoutCount else {
            print("❌ 9-Tipp-Vergleich: zu wenige Ziehungen")
            return nil
        }

        let holdoutStart = draws.count - holdoutCount
        let validationEnd = warmup + (holdoutStart - warmup) / 2
        let profiles = WeightSweepCore.makeProfiles()
        let generator = TicketGenerator()
        let candidateCount = WeightSweepCore.candidateCount()

        print("===================================")
        print("🏆 THOMAS F2 ↔ ALPHA 7.5 ↔ RALF")
        print("===================================")
        print("Holdout             : letzte \(holdoutCount) Ziehungen")
        print("F2                  : letzte \(f2Window) Trainingsziehungen")
        print("F2 Varianten        : 1–5 bis 9–13")
        print("Alpha               : echte WeightSweepCore-Profile")
        print("Ralf                : 9 feste Reihen")
        print("Tickets je System   : 9")
        print("===================================")

        var validationTotals = Array(repeating: ValidationAggregate(), count: profiles.count)

        for index in warmup..<validationEnd {
            let training = Array(draws.prefix(index))
            let target = draws[index]
            let candidates = generator.generate(
                count: candidateCount,
                draws: training,
                goal: OptimizationGoal(),
                hillClimbingIterations: 0
            )
            let cache = ScoreCache(draws: training)
            let engines = profiles.map { ScoreEngine(cache: cache, goal: $0.goal) }

            for profileIndex in profiles.indices {
                let tickets = WeightSweepCore.bestTickets(
                    candidates: candidates,
                    scoreEngine: engines[profileIndex],
                    limit: recommendationCount
                )
                validationTotals[profileIndex].add(tickets: tickets, target: target)
            }
        }

        guard let winnerIndex = profiles.indices.max(by: {
            validationTotals[$0].score < validationTotals[$1].score
        }) else { return nil }

        let winner = profiles[winnerIndex]
        print("Alpha-7.5 Validation-Gewinner: P\(String(format: "%02d", winner.id))")
        print("Gewichte: \(winner.weights.map { String(format: "%.0f", $0) }.joined(separator: " | "))")

        var accumulators = [
            "Thomas (F2)": HitAccumulator(),
            "Alpha 7.5": HitAccumulator(),
            "Ralf": HitAccumulator()
        ]

        for index in holdoutStart..<draws.count {
            let training = Array(draws.prefix(index))
            let target = draws[index]

            let f2Tickets = makeF2Tickets(from: training)
            let alphaTickets = makeAlphaTickets(from: training, winner: winner, generator: generator, candidateCount: candidateCount)

            accumulators["Thomas (F2)"]!.add(tickets: f2Tickets, target: target)
            accumulators["Alpha 7.5"]!.add(tickets: alphaTickets, target: target)
            accumulators["Ralf"]!.add(tickets: ralfTickets, target: target)
        }

        let players = ["Thomas (F2)", "Alpha 7.5", "Ralf"].compactMap { name -> NineTipComparisonResult.PlayerResult? in
            guard let accumulator = accumulators[name] else { return nil }
            let total = accumulator.classes.reduce(0, +)
            guard total > 0 else { return nil }
            return NineTipComparisonResult.PlayerResult(
                name: name,
                classes: accumulator.classes,
                total: total,
                percentages: accumulator.classes.map { Double($0) * 100.0 / Double(total) },
                mainAverage: Double(accumulator.mainHits) / Double(total),
                euroAverage: Double(accumulator.euroHits) / Double(total)
            )
        }

        print("===================================")
        print("🧪 50-HOLDOUT ERGEBNIS")
        print("===================================")
        print("Trefferklasse | Thomas F2 | Alpha 7.5 | Ralf")
        for index in 0..<NineTipComparisonResult.classLabels.count {
            print(String(format: "%-13@ | %3d (%.1f%%) | %3d (%.1f%%) | %3d (%.1f%%)",
                         NineTipComparisonResult.classLabels[index],
                         players[0].classes[index], players[0].percentages[index],
                         players[1].classes[index], players[1].percentages[index],
                         players[2].classes[index], players[2].percentages[index]))
        }
        print("===================================")

        return NineTipComparisonResult(
            holdoutDraws: holdoutCount,
            alphaProfileID: winner.id,
            players: players
        )
    }

    private func makeF2Tickets(from draws: [EuroJackpotDraw]) -> [Ticket] {
        let source = Array(draws.suffix(f2Window))
        let mainRanking = rankedNumbers(in: source, range: 1...50, isEuro: false)
        let euroRanking = rankedNumbers(in: source, range: 1...12, isEuro: true)

        return (0..<recommendationCount).map { offset in
            let main = Array(mainRanking[offset..<(offset + 5)]).sorted()
            let euro = Array(euroRanking[offset..<(offset + 2)]).sorted()
            return Ticket(numbers: main, euroNumbers: euro)
        }
    }

    private func makeAlphaTickets(from draws: [EuroJackpotDraw], winner: WeightSweepProfile, generator: TicketGenerator, candidateCount: Int) -> [Ticket] {
        let candidates = generator.generate(
            count: candidateCount,
            draws: draws,
            goal: OptimizationGoal(),
            hillClimbingIterations: 0
        )
        let cache = ScoreCache(draws: draws)
        let scoreEngine = ScoreEngine(cache: cache, goal: winner.goal)
        return WeightSweepCore.bestTickets(
            candidates: candidates,
            scoreEngine: scoreEngine,
            limit: recommendationCount
        )
    }

    private func rankedNumbers(in draws: [EuroJackpotDraw], range: ClosedRange<Int>, isEuro: Bool) -> [Int] {
        var counts = Array(repeating: 0, count: range.upperBound + 1)
        for draw in draws {
            let values = isEuro ? draw.euroNumbers : draw.numbers
            for value in values where value >= range.lowerBound && value <= range.upperBound {
                counts[value] += 1
            }
        }
        return range.sorted {
            if counts[$0] == counts[$1] { return $0 < $1 }
            return counts[$0] > counts[$1]
        }
    }

    private struct ValidationAggregate {
        var mainHits = 0
        var euroHits = 0
        var tickets = 0

        var score: Double {
            guard tickets > 0 else { return 0 }
            return Double(mainHits) / Double(tickets) - 0.50 + Double(euroHits) / Double(tickets) - (1.0 / 3.0)
        }

        mutating func add(tickets: [Ticket], target: EuroJackpotDraw) {
            for ticket in tickets {
                mainHits += Set(ticket.numbers).intersection(target.numbers).count
                euroHits += Set(ticket.euroNumbers).intersection(target.euroNumbers).count
            }
            self.tickets += tickets.count
        }
    }

    private struct HitAccumulator {
        var classes = Array(repeating: 0, count: 18)
        var mainHits = 0
        var euroHits = 0

        mutating func add(tickets: [Ticket], target: EuroJackpotDraw) {
            for ticket in tickets {
                let main = Set(ticket.numbers).intersection(target.numbers).count
                let euro = Set(ticket.euroNumbers).intersection(target.euroNumbers).count
                classes[main * 3 + euro] += 1
                mainHits += main
                euroHits += euro
            }
        }
    }
}
