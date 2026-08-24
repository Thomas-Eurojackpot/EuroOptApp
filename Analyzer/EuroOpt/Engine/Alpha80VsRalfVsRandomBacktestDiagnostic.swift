//

//  Alpha80VsRalfVsRandomBacktestDiagnostic.swift

//  EuroOpt

//

//  Separater Backtest: Alpha 8.0 vs Ralf vs Zufall

//

import Foundation

final class Alpha80VsRalfVsRandomBacktestDiagnostic {

    private let ticketCount = 9

    private let warmup = 100

    func run(draws: [EuroJackpotDraw], candidateCount: Int) {

        guard draws.count > warmup else {

            print("❌ Zu wenige Ziehungen")

            return

        }

        let evaluatedDraws = draws.count - warmup

        let ralfTickets: [Ticket] = [

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

        var alphaClasses: [String: Int] = [:]

        var ralfClasses: [String: Int] = [:]

        var randomClasses: [String: Int] = [:]

        var alphaWinDraws = 0

        var ralfWinDraws = 0

        var randomWinDraws = 0

        var alphaWinTickets = 0

        var ralfWinTickets = 0

        var randomWinTickets = 0

        var alphaMultiple: [Int: Int] = [:]

        var ralfMultiple: [Int: Int] = [:]

        var randomMultiple: [Int: Int] = [:]

        var randomState: UInt64 = 0x7A8F2026

        func nextRandom() -> UInt64 {

            randomState = randomState &* 6364136223846793005

                &+ 1442695040888963407

            return randomState

        }

        func makeRandomTicket() -> Ticket {

            var numbers = Set<Int>()

            while numbers.count < 5 {

                numbers.insert(Int(nextRandom() % 50) + 1)

            }

            var euroNumbers = Set<Int>()

            while euroNumbers.count < 2 {

                euroNumbers.insert(Int(nextRandom() % 12) + 1)

            }

            return Ticket(

                numbers: numbers.sorted(),

                euroNumbers: euroNumbers.sorted()

            )

        }

        func result(_ ticket: Ticket, _ draw: EuroJackpotDraw) -> (Int, Int) {

            (

                Set(ticket.numbers).intersection(draw.numbers).count,

                Set(ticket.euroNumbers).intersection(draw.euroNumbers).count

            )

        }

        func isWinning(_ main: Int, _ euro: Int) -> Bool {
        // Eurojackpot-Gewinnklasse:
        // 3+0 oder besser sowie 2+1 oder besser.
        return main >= 3 || (main >= 2 && euro >= 1)
    }

        for index in warmup..<draws.count {

            let training = Array(draws.prefix(index))

            let target = draws[index]

            // Alpha 8.0:

            // vorhandene TicketGenerator-Logik, Hill Climbing = 3,

            // danach Score -> Top 27 -> Coverage-Auswahl -> 9 Tipps.

            let generator = TicketGenerator()

            let candidates = generator.generate(

                count: candidateCount,

                draws: training,

                goal: OptimizationGoal(),

                hillClimbingIterations: 3

            )

            let scoreEngine = ScoreEngine(

                cache: ScoreCache(draws: training),

                goal: OptimizationGoal()

            )

            let scored = candidates

                .map { ($0, scoreEngine.score(ticket: $0)) }

                .sorted { $0.1 > $1.1 }

            let top27 = Array(scored.prefix(min(27, scored.count)))

            let alphaTickets = selectCoverageTarget(

                scored: top27,

                limit: ticketCount

            )

            let randomTickets = (0..<ticketCount).map {

                _ in makeRandomTicket()

            }

            let alphaResults = alphaTickets.map {

                result($0, target)

            }

            let ralfResults = ralfTickets.map {

                result($0, target)

            }

            let randomResults = randomTickets.map {

                result($0, target)

            }

            let alphaWins = alphaResults.filter {

                isWinning($0.0, $0.1)

            }

            let ralfWins = ralfResults.filter {

                isWinning($0.0, $0.1)

            }

            let randomWins = randomResults.filter {

                isWinning($0.0, $0.1)

            }

            if !alphaWins.isEmpty {

                alphaWinDraws += 1

            }

            if !ralfWins.isEmpty {

                ralfWinDraws += 1

            }

            if !randomWins.isEmpty {

                randomWinDraws += 1

            }

            alphaWinTickets += alphaWins.count

            ralfWinTickets += ralfWins.count

            randomWinTickets += randomWins.count

            if !alphaWins.isEmpty {

                alphaMultiple[alphaWins.count, default: 0] += 1

            }

            if !ralfWins.isEmpty {

                ralfMultiple[ralfWins.count, default: 0] += 1

            }

            if !randomWins.isEmpty {

                randomMultiple[randomWins.count, default: 0] += 1

            }

            for (main, euro) in alphaResults {

                alphaClasses["\(main)+\(euro)", default: 0] += 1

            }

            for (main, euro) in ralfResults {

                ralfClasses["\(main)+\(euro)", default: 0] += 1

            }

            for (main, euro) in randomResults {

                randomClasses["\(main)+\(euro)", default: 0] += 1

            }

        }

        let winningClasses = [

            "2+1", "2+2",

            "3+0", "3+1", "3+2",

            "4+0", "4+1", "4+2",

            "5+0", "5+1", "5+2"

        ]

        print("")

        print("==============================================")

        print("ALPHA 8.0 vs RALF vs ZUFALL")

        print("==============================================")

        print("Ziehungen: \(evaluatedDraws)")

        print("9 Tipps je Ziehung")

        print("")

        print("GEWINNKLASSEN – EINZELNE GEWINN-TICKETS")

        print("==============================================")

        print("Gewinnklasse | Alpha 8.0 | Ralf | Zufall")

        print("----------------------------------------------")

        for name in winningClasses {

            print(

                String(

                    format: "%-11@ | %10d | %4d | %6d",

                    name,

                    alphaClasses[name, default: 0],

                    ralfClasses[name, default: 0],

                    randomClasses[name, default: 0]

                )

            )

        }

        print("")

        print("GEWINN-ZIEHUNGEN ≥ 2+1")

        print("==============================================")

        print(

            String(

                format: "Alpha 8.0 | %4d / %.1f%%",

                alphaWinDraws,

                Double(alphaWinDraws) / Double(evaluatedDraws) * 100

            )

        )

        print(

            String(

                format: "Ralf      | %4d / %.1f%%",

                ralfWinDraws,

                Double(ralfWinDraws) / Double(evaluatedDraws) * 100

            )

        )

        print(

            String(

                format: "Zufall    | %4d / %.1f%%",

                randomWinDraws,

                Double(randomWinDraws) / Double(evaluatedDraws) * 100

            )

        )

        print("")

        print("GEWINN-TICKETS ≥ 2+1")

        print("==============================================")

        print("Alpha 8.0 | \(alphaWinTickets)")

        print("Ralf      | \(ralfWinTickets)")

        print("Zufall    | \(randomWinTickets)")

        print("")

        print("MEHRFACHGEWINNE PRO ZIEHUNG")

        print("==============================================")

        print("System    | 2 Gewinne | 3 Gewinne | 4+ Gewinne")

        print("----------------------------------------------")

        print(

            String(

                format: "Alpha 8.0 | %9d | %9d | %10d",

                alphaMultiple[2, default: 0],

                alphaMultiple[3, default: 0],

                alphaMultiple

                    .filter { $0.key >= 4 }

                    .values

                    .reduce(0, +)

            )

        )

        print(

            String(

                format: "Ralf      | %9d | %9d | %10d",

                ralfMultiple[2, default: 0],

                ralfMultiple[3, default: 0],

                ralfMultiple

                    .filter { $0.key >= 4 }

                    .values

                    .reduce(0, +)

            )

        )

        print(

            String(

                format: "Zufall    | %9d | %9d | %10d",

                randomMultiple[2, default: 0],

                randomMultiple[3, default: 0],

                randomMultiple

                    .filter { $0.key >= 4 }

                    .values

                    .reduce(0, +)

            )

        )

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

                    $0 + (mainCounts[$1, default: 0] == 0 ? 1 : 0)

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

