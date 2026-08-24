import Foundation

final class Alpha80HillClimbingSweepDiagnostic {

    private let ticketCount = 9
    private let warmup = 100
    private let hillClimbingValues = [0, 3, 5, 10, 20, 30]

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

    private struct Summary {
        var winDraws = 0
        var winTickets = 0
    }

    func run(draws: [EuroJackpotDraw], candidateCount: Int) {

        guard draws.count > warmup else {
            print("❌ Zu wenige Ziehungen")
            return
        }

        let evaluatedDraws = draws.count - warmup

        var summaries: [Int: Summary] = [:]
        for value in hillClimbingValues {
            summaries[value] = Summary()
        }

        func result(_ ticket: Ticket, _ draw: EuroJackpotDraw) -> (Int, Int) {
            (
                Set(ticket.numbers).intersection(draw.numbers).count,
                Set(ticket.euroNumbers).intersection(draw.euroNumbers).count
            )
        }

        func isWinning(_ main: Int, _ euro: Int) -> Bool {
            main >= 3 || (main >= 2 && euro >= 1)
        }

        for index in warmup..<draws.count {

            let training = Array(draws.prefix(index))
            let target = draws[index]

            for hillClimbing in hillClimbingValues {

                // Exakt dieselbe Alpha-8.0-Generatorlogik wie im aktuellen
                // Einzeltest: nur die Hill-Climbing-Iterationszahl variiert.
                let candidates = TicketGenerator().generate(
                    count: candidateCount,
                    draws: training,
                    goal: OptimizationGoal(),
                    hillClimbingIterations: hillClimbing
                )

                let scoreEngine = ScoreEngine(
                    cache: ScoreCache(draws: training),
                    goal: OptimizationGoal()
                )

                let scored = candidates
                    .map { ($0, scoreEngine.score(ticket: $0)) }
                    .sorted { $0.1 > $1.1 }

                let top27 = Array(
                    scored.prefix(min(27, scored.count))
                )

                let alphaTickets = selectCoverageTarget(
                    scored: top27,
                    limit: ticketCount
                )

                let alphaResults = alphaTickets.map {
                    result($0, target)
                }

                let wins = alphaResults.filter {
                    isWinning($0.0, $0.1)
                }

                if !wins.isEmpty {
                    summaries[hillClimbing]!.winDraws += 1
                }

                summaries[hillClimbing]!.winTickets += wins.count
            }
        }

        print("==============================================")
        print("ALPHA 8.0 HILL-CLIMBING SWEEP")
        print("==============================================")
        print("Ziehungen: \(evaluatedDraws)")
        print("9 Tipps je Ziehung")
        print("==============================================")
        print("HC | Gewinn-Ziehungen | Quote | Gewinn-Tickets")
        print("----------------------------------------------")

        for hillClimbing in hillClimbingValues {
            let summary = summaries[hillClimbing]!

            print(
                String(
                    format: "%2d | %16d | %5.1f%% | %14d",
                    hillClimbing,
                    summary.winDraws,
                    Double(summary.winDraws) /
                        Double(evaluatedDraws) * 100,
                    summary.winTickets
                )
            )
        }

        print("==============================================")
    }

    private func selectCoverageTarget(
        scored: [(Ticket, Double)],
        limit: Int,
        coverageWeight: Double = 0.35
    ) -> [Ticket] {

        guard !scored.isEmpty else {
            return []
        }

        var result: [Ticket] = []
        var mainCounts: [Int: Int] = [:]
        var euroCounts: [Int: Int] = [:]

        let targetMainCount = 1
        let targetEuroCount = 2

        while result.count < min(limit, scored.count) {

            var bestTicket: Ticket?
            var bestValue = -Double.infinity

            let minScore = scored.map { $0.1 }.min() ?? 0
            let maxScore = scored.map { $0.1 }.max() ?? 0
            let scoreRange = maxScore - minScore

            for candidate in scored {

                if result.contains(where: {
                    $0.numbers == candidate.0.numbers &&
                    $0.euroNumbers == candidate.0.euroNumbers
                }) {
                    continue
                }

                let normalizedScore =
                    scoreRange > 0
                    ? (candidate.1 - minScore) / scoreRange
                    : 1.0

                var coverageGain = 0.0

                for number in candidate.0.numbers {
                    if mainCounts[number, default: 0] < targetMainCount {
                        coverageGain += 1.0
                    }
                }

                for number in candidate.0.euroNumbers {
                    if euroCounts[number, default: 0] < targetEuroCount {
                        coverageGain += 0.5
                    }
                }

                let newMainNumbers = candidate.0.numbers.reduce(0) {
                    $0 + (
                        mainCounts[$1, default: 0] == 0
                        ? 1
                        : 0
                    )
                }

                let value =
                    normalizedScore +
                    coverageWeight * coverageGain +
                    0.10 * Double(newMainNumbers)

                if value > bestValue {
                    bestValue = value
                    bestTicket = candidate.0
                }
            }

            guard let bestTicket else {
                break
            }

            result.append(bestTicket)

            for number in bestTicket.numbers {
                mainCounts[number, default: 0] += 1
            }

            for number in bestTicket.euroNumbers {
                euroCounts[number, default: 0] += 1
            }
        }

        return result
    }
}

