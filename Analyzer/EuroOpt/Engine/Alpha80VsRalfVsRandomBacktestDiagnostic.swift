import Foundation

final class Alpha80VsRalfVsRandomBacktestDiagnostic {
    private let warmup = 100
    private let ticketCount = 9

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

    func run(
        draws: [EuroJackpotDraw],
        candidateCount: Int
    ) {
        guard draws.count > warmup else {
            print("❌ Zu wenige Ziehungen")
            return
        }

        let evaluatedDraws = draws.count - warmup
        let totalTickets = evaluatedDraws * ticketCount

        var alpha80 = Array(repeating: Array(repeating: 0, count: 3), count: 6)
        var ralf = Array(repeating: Array(repeating: 0, count: 3), count: 6)
        var random = Array(repeating: Array(repeating: 0, count: 3), count: 6)

        var totalMain80 = 0
        var totalEuro80 = 0
        var totalMainRalf = 0
        var totalEuroRalf = 0
        var totalMainRandom = 0
        var totalEuroRandom = 0

        var atLeast21Alpha80 = 0
        var atLeast21Ralf = 0
        var atLeast21Random = 0

        var winningTicketsAlpha80 = 0
        var winningTicketsRalf = 0
        var winningTicketsRandom = 0

        let randomGenerator = SeededRandomGenerator(seed: 0xE7A7_7401)

        func result(_ ticket: Ticket, _ draw: EuroJackpotDraw) -> (Int, Int) {
            let main = Set(ticket.numbers).intersection(draw.numbers).count
            let euro = Set(ticket.euroNumbers).intersection(draw.euroNumbers).count
            return (main, euro)
        }

        func isWin(_ main: Int, _ euro: Int) -> Bool {
            return (main >= 2 && euro >= 1) || main >= 3
        }

        for index in warmup..<draws.count {
            let target = draws[index]
            let training = Array(draws.prefix(index))

            // ALPHA 8.0 — unverändert: TicketGenerator, kein Hill Climbing,
            // Score, Top 27, danach selectCoverageTarget auf genau diesen 27.
            let candidates80 = TicketGenerator().generate(
                count: candidateCount,
                draws: training,
                goal: OptimizationGoal(),
                hillClimbingIterations: 0
            )

            let scoreEngine80 = ScoreEngine(
                cache: ScoreCache(draws: training),
                goal: OptimizationGoal()
            )

            let scored80 = candidates80
                .map { ($0, scoreEngine80.score(ticket: $0)) }
                .sorted { $0.1 > $1.1 }

            let selected80 = selectCoverageTarget(
                scored: Array(scored80.prefix(min(27, scored80.count))),
                limit: ticketCount
            )

            let randomTickets = (0..<ticketCount).map { _ in
                randomGenerator.makeTicket()
            }

            for ticket in selected80 {
                let (main, euro) = result(ticket, target)
                alpha80[main][euro] += 1
                totalMain80 += main
                totalEuro80 += euro
                if isWin(main, euro) { winningTicketsAlpha80 += 1 }
            }

            for ticket in ralfTickets {
                let (main, euro) = result(ticket, target)
                ralf[main][euro] += 1
                totalMainRalf += main
                totalEuroRalf += euro
                if isWin(main, euro) { winningTicketsRalf += 1 }
            }

            for ticket in randomTickets {
                let (main, euro) = result(ticket, target)
                random[main][euro] += 1
                totalMainRandom += main
                totalEuroRandom += euro
                if isWin(main, euro) { winningTicketsRandom += 1 }
            }

            if selected80.contains(where: { let r = result($0, target); return isWin(r.0, r.1) }) {
                atLeast21Alpha80 += 1
            }
            if ralfTickets.contains(where: { let r = result($0, target); return isWin(r.0, r.1) }) {
                atLeast21Ralf += 1
            }
            if randomTickets.contains(where: { let r = result($0, target); return isWin(r.0, r.1) }) {
                atLeast21Random += 1
            }
        }

        print("==============================================")
        print("ALPHA 8.0 vs RALF vs ZUFALL")
        print("==============================================")
        print("Ziehungen              : \(evaluatedDraws)")
        print("Tickets je System      : \(ticketCount)")
        print("==============================================")
        print("GEWINNKLASSEN")
        print("==============================================")
        print("Gewinnklasse | Alpha 8.0 | Ralf | Zufall")
        print("             | Anzahl/%  | Anzahl/% | Anzahl/%")
        print("------------------------------------------------")

        let winningClasses: [(Int, Int)] = [
            (2, 1), (2, 2), (3, 0), (3, 1), (3, 2),
            (4, 0), (4, 1), (4, 2), (5, 0), (5, 1), (5, 2)
        ]

        for (main, euro) in winningClasses {
            let a = alpha80[main][euro]
            let r = ralf[main][euro]
            let z = random[main][euro]
            print(String(format: "%d+%d | %4d / %.1f%% | %4d / %.1f%% | %4d / %.1f%%",
                         main, euro,
                         a, Double(a) / Double(totalTickets) * 100,
                         r, Double(r) / Double(totalTickets) * 100,
                         z, Double(z) / Double(totalTickets) * 100))
        }

        print("==============================================")
        print("GEWINN-TIPPS ≥2+1")
        print("==============================================")
        print("Alpha 8.0 | \(winningTicketsAlpha80)")
        print("Ralf      | \(winningTicketsRalf)")
        print("Zufall    | \(winningTicketsRandom)")
        print("==============================================")
        print("GEWINN-ZIEHUNGEN ≥2+1")
        print("==============================================")
        print(String(format: "Alpha 8.0 | %d / %.1f%%", atLeast21Alpha80, Double(atLeast21Alpha80) / Double(evaluatedDraws) * 100))
        print(String(format: "Ralf      | %d / %.1f%%", atLeast21Ralf, Double(atLeast21Ralf) / Double(evaluatedDraws) * 100))
        print(String(format: "Zufall    | %d / %.1f%%", atLeast21Random, Double(atLeast21Random) / Double(evaluatedDraws) * 100))
        print("==============================================")
        print("GEWINNE JE GEWINN-ZIEHUNG")
        print("==============================================")
        print(String(format: "Alpha 8.0 | %.3f", atLeast21Alpha80 > 0 ? Double(winningTicketsAlpha80) / Double(atLeast21Alpha80) : 0))
        print(String(format: "Ralf      | %.3f", atLeast21Ralf > 0 ? Double(winningTicketsRalf) / Double(atLeast21Ralf) : 0))
        print(String(format: "Zufall    | %.3f", atLeast21Random > 0 ? Double(winningTicketsRandom) / Double(atLeast21Random) : 0))
        print("==============================================")
        print("DURCHSCHNITT")
        print("==============================================")
        print(String(format: "Alpha 8.0 Hauptzahlen : %.3f", Double(totalMain80) / Double(totalTickets)))
        print(String(format: "Alpha 8.0 Eurozahlen  : %.3f", Double(totalEuro80) / Double(totalTickets)))
        print(String(format: "Ralf Hauptzahlen      : %.3f", Double(totalMainRalf) / Double(totalTickets)))
        print(String(format: "Ralf Eurozahlen       : %.3f", Double(totalEuroRalf) / Double(totalTickets)))
        print(String(format: "Zufall Hauptzahlen    : %.3f", Double(totalMainRandom) / Double(totalTickets)))
        print(String(format: "Zufall Eurozahlen     : %.3f", Double(totalEuroRandom) / Double(totalTickets)))
        print("==============================================")
    }

    private func selectCoverageTarget(
        scored: [(Ticket, Double)],
        limit: Int,
        coverageWeight: Double = 0.35
    ) -> [Ticket] {
        guard !scored.isEmpty, limit > 0 else { return [] }

        let targetCount = min(limit, scored.count)
        var result: [Ticket] = []
        result.reserveCapacity(targetCount)
        var mainCounts: [Int: Int] = [:]
        var euroCounts: [Int: Int] = [:]
        let targetMainCount = 1
        let targetEuroCount = 2

        result.append(scored[0].0)
        for n in scored[0].0.numbers { mainCounts[n, default: 0] += 1 }
        for n in scored[0].0.euroNumbers { euroCounts[n, default: 0] += 1 }

        while result.count < targetCount {
            var bestTicket: Ticket?
            var bestValue = -Double.infinity
            let minScore = scored.map { $0.1 }.min() ?? 0
            let maxScore = scored.map { $0.1 }.max() ?? 0
            let range = maxScore - minScore

            for candidate in scored {
                if result.contains(where: {
                    $0.numbers == candidate.0.numbers && $0.euroNumbers == candidate.0.euroNumbers
                }) { continue }

                let normalizedScore = range > 0 ? (candidate.1 - minScore) / range : 1.0
                var coverageGain = 0.0
                for n in candidate.0.numbers {
                    if mainCounts[n, default: 0] < targetMainCount { coverageGain += 1.0 }
                }
                for n in candidate.0.euroNumbers {
                    if euroCounts[n, default: 0] < targetEuroCount { coverageGain += 0.5 }
                }
                let newMainNumbers = candidate.0.numbers.reduce(0) {
                    $0 + (mainCounts[$1, default: 0] == 0 ? 1 : 0)
                }
                let value = normalizedScore + coverageWeight * coverageGain + 0.10 * Double(newMainNumbers)
                if value > bestValue {
                    bestValue = value
                    bestTicket = candidate.0
                }
            }

            guard let bestTicket else { break }
            result.append(bestTicket)
            for n in bestTicket.numbers { mainCounts[n, default: 0] += 1 }
            for n in bestTicket.euroNumbers { euroCounts[n, default: 0] += 1 }
        }
        return result
    }

    private final class SeededRandomGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed }
        private func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
        private func randomInt(_ upperBound: Int) -> Int {
            Int(next() % UInt64(upperBound))
        }
        func makeTicket() -> Ticket {
            var numbers = Set<Int>()
            while numbers.count < 5 { numbers.insert(randomInt(50) + 1) }
            var euroNumbers = Set<Int>()
            while euroNumbers.count < 2 { euroNumbers.insert(randomInt(12) + 1) }
            return Ticket(numbers: numbers.sorted(), euroNumbers: euroNumbers.sorted())
        }
    }
}
