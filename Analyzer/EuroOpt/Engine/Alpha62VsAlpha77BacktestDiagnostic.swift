import Foundation

final class Alpha62VsAlpha77RalfZufallVsAlpha80BacktestDiagnostic {

    private let warmup = 100

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

        candidateCount: Int,

        recommendationCount: Int

    ) {

        print("==============================================")

        print("ALPHA 6.2 / ALPHA 7.8 / RALF / ZUFALL / ALPHA 8.0")

        print("==============================================")

        guard draws.count > warmup else {

            print("❌ Zu wenige Ziehungen")

            return

        }

        let ticketCount = 9

        let evaluatedDraws = draws.count - warmup

        var alpha62 = Array(

            repeating: Array(repeating: 0, count: 3),

            count: 6

        )

        var alpha62ScoreOnly = Array(

            repeating: Array(repeating: 0, count: 3),

            count: 6

        )

        var alpha78 = Array(

            repeating: Array(repeating: 0, count: 3),

            count: 6

        )

        var alpha80 = Array(

            repeating: Array(repeating: 0, count: 3),

            count: 6

        )

        var ralf = Array(

            repeating: Array(repeating: 0, count: 3),

            count: 6

        )

        var random = Array(

            repeating: Array(repeating: 0, count: 3),

            count: 6

        )

        var totalMain62 = 0

        var totalEuro62 = 0

        var totalMain62ScoreOnly = 0

        var totalEuro62ScoreOnly = 0

        var totalMain78 = 0

        var totalEuro78 = 0

        var totalMain80 = 0

        var totalEuro80 = 0

        var totalMainRalf = 0

        var totalEuroRalf = 0

        var totalMainRandom = 0

        var totalEuroRandom = 0

        // MINDESTENS 2+1 PRO 9-TIPP-SYSTEM

        var atLeast21Alpha62 = 0

        var atLeast21ScoreOnly = 0

        var atLeast21Alpha78 = 0

        var atLeast21Ralf = 0

        var atLeast21Random = 0

        var atLeast21Alpha80 = 0

        let randomGenerator = SeededRandomGenerator(seed: 0xE7A7_7401)

        print("==============================================")

        print("ALPHA 6.2 ↔ ALPHA 7.8 ↔ RALF ↔ ZUFALL ↔ ALPHA 8.0")

        print("==============================================")

        print("Ausgewertete Ziehungen : \(evaluatedDraws)")

        print("Tickets je System      : \(ticketCount)")

        print("==============================================")

        for index in warmup..<draws.count {

            let targetDraw = draws[index]

            let trainingDraws = Array(draws.prefix(index))

            // System-Hit-Flags für die 9-Tipp-Auswertung

            func hasAtLeast21(_ tickets: [Ticket]) -> Bool {

                for ticket in tickets {

                    let main = Set(ticket.numbers)

                        .intersection(targetDraw.numbers)

                        .count

                    let euro = Set(ticket.euroNumbers)

                        .intersection(targetDraw.euroNumbers)

                        .count

                    if (main >= 2 && euro >= 1) || main >= 3 {

                        return true

                    }

                }

                return false

            }

            // ALPHA 6.2

            let generator62 = Alpha62TicketGenerator()

            let candidates62 = generator62.generate(

                count: candidateCount,

                draws: trainingDraws

            )

            let optimizer62 = Alpha62OptimizerEngine()

            let best62 = optimizer62.bestTickets(

                from: candidates62,

                draws: trainingDraws,

                limit: ticketCount

            )

            for item in best62 {

                let main = Set(item.ticket.numbers)

                    .intersection(targetDraw.numbers)

                    .count

                let euro = Set(item.ticket.euroNumbers)

                    .intersection(targetDraw.euroNumbers)

                    .count

                alpha62[main][euro] += 1

                totalMain62 += main

                totalEuro62 += euro

            }

            // ALPHA 6.2 – SCORE-ONLY

            let scoreOnlyTickets62 = bestScoreOnly62(

                from: candidates62,

                draws: trainingDraws,

                limit: ticketCount

            )

            for ticket in scoreOnlyTickets62 {

                let main = Set(ticket.numbers)

                    .intersection(targetDraw.numbers)

                    .count

                let euro = Set(ticket.euroNumbers)

                    .intersection(targetDraw.euroNumbers)

                    .count

                alpha62ScoreOnly[main][euro] += 1

                totalMain62ScoreOnly += main

                totalEuro62ScoreOnly += euro

            }

            // ALPHA 7.8 – bestehende TicketGenerator/OptimizerEngine-Logik

            let generator77 = TicketGenerator()

            let candidates77 = generator77.generate(

                count: candidateCount,

                draws: trainingDraws,

                goal: OptimizationGoal(),

                hillClimbingIterations:

                    AppSettings.backtestHillClimbingIterations

            )

            let optimizer77 = OptimizerEngine()

            let best77 = optimizer77.bestTickets(

                from: candidates77,

                draws: trainingDraws,

                goal: OptimizationGoal(),

                limit: ticketCount

            )

            for item in best77 {

                let main = Set(item.ticket.numbers)

                    .intersection(targetDraw.numbers)

                    .count

                let euro = Set(item.ticket.euroNumbers)

                    .intersection(targetDraw.euroNumbers)

                    .count

                alpha78[main][euro] += 1

                totalMain78 += main

                totalEuro78 += euro

            }

            // ALPHA 8.0 – Top-27 / Coverage Target

            let candidates80 = TicketGenerator().generate(

                count: candidateCount,

                draws: trainingDraws,

                goal: OptimizationGoal(),

                hillClimbingIterations: 0

            )

            let scoreEngine80 = ScoreEngine(

                cache: ScoreCache(draws: trainingDraws),

                goal: OptimizationGoal()

            )

            let scored80 = candidates80

                .map { ($0, scoreEngine80.score(ticket: $0)) }

                .sorted { $0.1 > $1.1 }

            let selected80 = selectCoverageTarget(

                scored: Array(scored80.prefix(min(27, scored80.count))),

                limit: ticketCount

            )

            for ticket in selected80 {

                let main = Set(ticket.numbers)

                    .intersection(targetDraw.numbers)

                    .count

                let euro = Set(ticket.euroNumbers)

                    .intersection(targetDraw.euroNumbers)

                    .count

                alpha80[main][euro] += 1

                totalMain80 += main

                totalEuro80 += euro

            }

            // RALF – exakt 9 feste Tipps

            for ticket in ralfTickets {

                let main = Set(ticket.numbers)

                    .intersection(targetDraw.numbers)

                    .count

                let euro = Set(ticket.euroNumbers)

                    .intersection(targetDraw.euroNumbers)

                    .count

                ralf[main][euro] += 1

                totalMainRalf += main

                totalEuroRalf += euro

            }

            // ZUFALL – exakt 9 Tipps

            let randomTickets = (0..<ticketCount).map { _ in

                randomGenerator.makeTicket()

            }

            for ticket in randomTickets {

                let main = Set(ticket.numbers)

                    .intersection(targetDraw.numbers)

                    .count

                let euro = Set(ticket.euroNumbers)

                    .intersection(targetDraw.euroNumbers)

                    .count

                random[main][euro] += 1

                totalMainRandom += main

                totalEuroRandom += euro

            }

            // Systemwertung: mindestens 2+1 innerhalb der 9 Tipps

            if hasAtLeast21(best62.map { $0.ticket }) {

                atLeast21Alpha62 += 1

            }

            if hasAtLeast21(scoreOnlyTickets62) {

                atLeast21ScoreOnly += 1

            }

            if hasAtLeast21(best77.map { $0.ticket }) {

                atLeast21Alpha78 += 1

            }

            if hasAtLeast21(ralfTickets) {

                atLeast21Ralf += 1

            }

            if hasAtLeast21(randomTickets) {

                atLeast21Random += 1

            }

            if hasAtLeast21(selected80) {

                atLeast21Alpha80 += 1

            }

            // EXAKTE ALPHA-6.2-TREFFER JE ZIEHUNG

            let interesting62 = best62.compactMap { item -> String? in

                let main = Set(item.ticket.numbers)

                    .intersection(targetDraw.numbers)

                    .count

                let euro = Set(item.ticket.euroNumbers)

                    .intersection(targetDraw.euroNumbers)

                    .count

                if main >= 2 || (main >= 1 && euro >= 1) {

                    return "\(main)+\(euro)"

                }

                return nil

            }

            if !interesting62.isEmpty {

                print("")

                print("🎯 Alpha 6.2 | Ziehung \(targetDraw.date)")

                print("Treffer: \(interesting62.joined(separator: ", "))")

            }

            let current = index - warmup + 1

            print(

                String(

                    format: "\rZiehung %d / %d",

                    current,

                    evaluatedDraws

                ),

                terminator: ""

            )

            fflush(stdout)

        }

        print("")

        print("")

        print("==============================================")

        print("GEWINNKLASSEN")

        print("==============================================")

        let totalTickets = evaluatedDraws * ticketCount

        print("Gewinnklasse | Alpha 6.2 | Score-only | Alpha 7.8 | Ralf | Zufall | Alpha 8.0")

        print("             | Anzahl/%  | Anzahl/%   | Anzahl/%  | Anzahl/% | Anzahl/% | Anzahl/%")

        print("--------------------------------------------------------------------------")

        let winningClasses: [(Int, Int)] = [
            (0, 0),
            (0, 1),
            (0, 2),
            (1, 0),
            (1, 1),
            (1, 2),
            (2, 0),
            (2, 1),
            (2, 2),
            (3, 0),
            (3, 1),
            (3, 2),
            (4, 0),
            (4, 1),
            (4, 2),
            (5, 0),
            (5, 1),
            (5, 2)
        ]

        for (main, euro) in winningClasses {

            let count62 = alpha62[main][euro]

            let countScoreOnly = alpha62ScoreOnly[main][euro]

            let count78 = alpha78[main][euro]

            let countRalf = ralf[main][euro]

            let countRandom = random[main][euro]

            let count80 = alpha80[main][euro]

            let pct62 = Double(count62) / Double(totalTickets) * 100.0

            let pctScoreOnly = Double(countScoreOnly) / Double(totalTickets) * 100.0

            let pct78 = Double(count78) / Double(totalTickets) * 100.0

            let pctRalf = Double(countRalf) / Double(totalTickets) * 100.0

            let pctRandom = Double(countRandom) / Double(totalTickets) * 100.0

            let pct80 = Double(count80) / Double(totalTickets) * 100.0

            print(

                String(

                    format: "%d+%d | %4d / %.1f%% | %4d / %.1f%% | %4d / %.1f%% | %4d / %.1f%% | %4d / %.1f%% | %4d / %.1f%%",

                    main,

                    euro,

                    count62,

                    pct62,

                    countScoreOnly,

                    pctScoreOnly,

                    count78,

                    pct78,

                    countRalf,

                    pctRalf,

                    countRandom,

                    pctRandom,

                    count80,

                    pct80

                )

            )

        }

        print("==============================================")

        print("Gewinnklasse | Alpha 6.2 | Score-only | Alpha 7.8 | Ralf | Zufall | Alpha 8.0")

        print("---------------------------------------------------------------")

        print("")

        print("==============================================")

        print("MINDESTENS 2+1 PRO 9-TIPP-SYSTEM")

        print("==============================================")

        print("")

        print("System       | Ziehungen | Wahrscheinlichkeit")

        print("------------------------------------------------")

        print(String(format: "Alpha 6.2    | %9d | %5.1f%%", atLeast21Alpha62, Double(atLeast21Alpha62) / Double(evaluatedDraws) * 100.0))

        print(String(format: "Score-only   | %9d | %5.1f%%", atLeast21ScoreOnly, Double(atLeast21ScoreOnly) / Double(evaluatedDraws) * 100.0))

        print(String(format: "Alpha 7.8    | %9d | %5.1f%%", atLeast21Alpha78, Double(atLeast21Alpha78) / Double(evaluatedDraws) * 100.0))

        print(String(format: "Ralf         | %9d | %5.1f%%", atLeast21Ralf, Double(atLeast21Ralf) / Double(evaluatedDraws) * 100.0))

        print(String(format: "Zufall       | %9d | %5.1f%%", atLeast21Random, Double(atLeast21Random) / Double(evaluatedDraws) * 100.0))

        print(String(format: "Alpha 8.0    | %9d | %5.1f%%", atLeast21Alpha80, Double(atLeast21Alpha80) / Double(evaluatedDraws) * 100.0))

        print("==============================================")

        print("")

        print("SYSTEMVERGLEICH")

        print("==============================================")

        print("System       | >=2+1 | Quote | Vorteil vs Zufall")

        print("------------------------------------------------")

        let randomRate = Double(atLeast21Random) / Double(evaluatedDraws) * 100.0

        print(String(format: "Alpha 6.2    | %5d | %5.1f%% | %+5.1f Pkt.", atLeast21Alpha62, Double(atLeast21Alpha62) / Double(evaluatedDraws) * 100.0, Double(atLeast21Alpha62) / Double(evaluatedDraws) * 100.0 - randomRate))

        print(String(format: "Score-only   | %5d | %5.1f%% | %+5.1f Pkt.", atLeast21ScoreOnly, Double(atLeast21ScoreOnly) / Double(evaluatedDraws) * 100.0, Double(atLeast21ScoreOnly) / Double(evaluatedDraws) * 100.0 - randomRate))

        print(String(format: "Alpha 7.8    | %5d | %5.1f%% | %+5.1f Pkt.", atLeast21Alpha78, Double(atLeast21Alpha78) / Double(evaluatedDraws) * 100.0, Double(atLeast21Alpha78) / Double(evaluatedDraws) * 100.0 - randomRate))

        print(String(format: "Ralf         | %5d | %5.1f%% | %+5.1f Pkt.", atLeast21Ralf, Double(atLeast21Ralf) / Double(evaluatedDraws) * 100.0, Double(atLeast21Ralf) / Double(evaluatedDraws) * 100.0 - randomRate))

        print(String(format: "Zufall       | %5d | %5.1f%% |      —", atLeast21Random, randomRate))

        print(String(format: "Alpha 8.0    | %5d | %5.1f%% | %+5.1f Pkt.", atLeast21Alpha80, Double(atLeast21Alpha80) / Double(evaluatedDraws) * 100.0, Double(atLeast21Alpha80) / Double(evaluatedDraws) * 100.0 - randomRate))

        print("==============================================")

        print("")

        print("DURCHSCHNITT")

        print("==============================================")

        print(

            String(

                format: "Alpha 6.2 Hauptzahlen : %.3f",

                Double(totalMain62) / Double(totalTickets)

            )

        )

        print(

            String(

                format: "Alpha 6.2 Eurozahlen  : %.3f",

                Double(totalEuro62) / Double(totalTickets)

            )

        )

        print(

            String(

                format: "Score-only Hauptzahlen : %.3f",

                Double(totalMain62ScoreOnly) / Double(totalTickets)

            )

        )

        print(

            String(

                format: "Score-only Eurozahlen  : %.3f",

                Double(totalEuro62ScoreOnly) / Double(totalTickets)

            )

        )

        print(

            String(

                format: "Alpha 7.8 Hauptzahlen : %.3f",

                Double(totalMain78) / Double(totalTickets)

            )

        )

        print(

            String(

                format: "Alpha 7.8 Eurozahlen  : %.3f",

                Double(totalEuro78) / Double(totalTickets)

            )

        )

        print(

            String(

                format: "Alpha 8.0 Hauptzahlen : %.3f",

                Double(totalMain80) / Double(totalTickets)

            )

        )

        print(

            String(

                format: "Alpha 8.0 Eurozahlen  : %.3f",

                Double(totalEuro80) / Double(totalTickets)

            )

        )

        print(

            String(

                format: "Ralf Hauptzahlen      : %.3f",

                Double(totalMainRalf) / Double(totalTickets)

            )

        )

        print(

            String(

                format: "Ralf Eurozahlen       : %.3f",

                Double(totalEuroRalf) / Double(totalTickets)

            )

        )

        print(

            String(

                format: "Zufall Hauptzahlen    : %.3f",

                Double(totalMainRandom) / Double(totalTickets)

            )

        )

        print(

            String(

                format: "Zufall Eurozahlen     : %.3f",

                Double(totalEuroRandom) / Double(totalTickets)

            )

        )

        print("==============================================")

        print("Alle sechs Systeme: \(ticketCount) Tipps je Ziehung")

        print("==============================================")

    }

    private func bestScoreOnly62(

        from candidates: [Ticket],

        draws: [EuroJackpotDraw],

        limit: Int

    ) -> [Ticket] {

        // Einmaliger Cache pro Ziehung statt Cache-Prüfung für jeden Kandidaten.

        let scoreEngine = ScoreEngine(

            cache: ScoreCache(draws: draws),

            goal: OptimizationGoal()

        )

        return Array(

            candidates

                .map {

                    (

                        ticket: $0,

                        score: scoreEngine.score(ticket: $0)

                    )

                }

                .sorted { $0.score > $1.score }

                .prefix(limit)

                .map { $0.ticket }

        )

    }

    private func selectCoverageTarget(

        scored: [(Ticket, Double)],

        limit: Int,

        coverageWeight: Double = 0.35

    ) -> [Ticket] {

        guard !scored.isEmpty, limit > 0 else {

            return []

        }

        let pool = scored

        let targetCount = min(limit, pool.count)

        var result: [Ticket] = []

        result.reserveCapacity(targetCount)

        var mainCounts: [Int: Int] = [:]

        var euroCounts: [Int: Int] = [:]

        let targetMainCount = 1

        let targetEuroCount = 2

        result.append(pool[0].0)

        for number in pool[0].0.numbers {

            mainCounts[number, default: 0] += 1

        }

        for number in pool[0].0.euroNumbers {

            euroCounts[number, default: 0] += 1

        }

        while result.count < targetCount {

            var bestTicket: Ticket?

            var bestValue = -Double.infinity

            let minScore = pool.map { $0.1 }.min() ?? 0.0

            let maxScore = pool.map { $0.1 }.max() ?? 0.0

            let scoreRange = maxScore - minScore

            for candidate in pool {

                if result.contains(where: {

                    $0.numbers == candidate.0.numbers &&

                    $0.euroNumbers == candidate.0.euroNumbers

                }) {

                    continue

                }

                let normalizedScore =

                    scoreRange > 0.0

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

private final class SeededRandomGenerator {

    private var state: UInt64

    init(seed: UInt64) {

        self.state = seed

    }

    private func next() -> UInt64 {

        state = state &* 6364136223846793005 &+ 1442695040888963407

        return state

    }

    private func randomInt(_ upperBound: Int) -> Int {

        Int(next() % UInt64(upperBound))

    }

    func makeTicket() -> Ticket {

        var numbers = Set<Int>()

        while numbers.count < 5 {

            numbers.insert(randomInt(50) + 1)

        }

        var euroNumbers = Set<Int>()

        while euroNumbers.count < 2 {

            euroNumbers.insert(randomInt(12) + 1)

        }

        return Ticket(

            numbers: numbers.sorted(),

            euroNumbers: euroNumbers.sorted()

        )

    }









































}

}

