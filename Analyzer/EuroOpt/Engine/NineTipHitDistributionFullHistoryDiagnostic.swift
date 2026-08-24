import Foundation

struct NineTipHitDistributionFullHistoryDiagnostic {

    func run(
        draws: [EuroJackpotDraw],
        candidateCount: Int = AppSettings.backtestCandidateCount,
        recommendationCount: Int = 9
    ) {
        let holdoutCount = 50
        let warmup = 100

        guard draws.count > warmup + holdoutCount else {
            print("❌ Zu wenige Ziehungen für den Holdout.")
            return
        }

        let holdoutStart = draws.count - holdoutCount

        var alpha76: [[Int]] =
            Array(repeating: Array(repeating: 0, count: 3), count: 6)

        var alpha77: [[Int]] =
            Array(repeating: Array(repeating: 0, count: 3), count: 6)

        var totalMain76 = 0
        var totalEuro76 = 0
        var totalMain77 = 0
        var totalEuro77 = 0

        print("==============================================")
        print("🔬 9-TIPP TREFFERKLASSEN – GESAMTE HISTORIE")
        print("==============================================")
        print("Historie             : alle Ziehungen ab Warmup \(warmup)")
        print("Empfehlungen         : \(recommendationCount)")
        print("Alpha 7.6            : Original")
        print("Alpha 7.7            : Recency 50 / Top 2")
        print("----------------------------------------------")

        var evaluatedDraws = 0

        for index in warmup..<draws.count {
            evaluatedDraws += 1
            let trainingDraws = Array(draws[..<index])
            let targetDraw = draws[index]

            guard trainingDraws.count >= warmup else {
                continue
            }

            let goal = OptimizationGoalStore.shared.currentGoal

            let generator = TicketGenerator()
            let optimizer = OptimizerEngine()

            let candidates = generator.generate(
                count: candidateCount,
                draws: trainingDraws,
                goal: goal
            )

            let bestTickets = optimizer.bestTickets(
                from: candidates,
                draws: trainingDraws,
                goal: goal,
                limit: recommendationCount
            )

            let alpha76Tickets = bestTickets.map(\.ticket)

            let euro77 = recency50TopTwo(draws: trainingDraws)

            let alpha77Tickets = alpha76Tickets.map {
                Ticket(
                    numbers: $0.numbers,
                    euroNumbers: euro77
                )
            }

            for ticket in alpha76Tickets {
                let main = Set(ticket.numbers)
                    .intersection(targetDraw.numbers)
                    .count

                let euro = Set(ticket.euroNumbers)
                    .intersection(targetDraw.euroNumbers)
                    .count

                if main <= 5 && euro <= 2 {
                    alpha76[main][euro] += 1
                }

                totalMain76 += main
                totalEuro76 += euro
            }

            for ticket in alpha77Tickets {
                let main = Set(ticket.numbers)
                    .intersection(targetDraw.numbers)
                    .count

                let euro = Set(ticket.euroNumbers)
                    .intersection(targetDraw.euroNumbers)
                    .count

                if main <= 5 && euro <= 2 {
                    alpha77[main][euro] += 1
                }

                totalMain77 += main
                totalEuro77 += euro
            }
        }

        print("")
        print("ALPHA 7.6 – ORIGINAL")
        print("----------------------------------------------")
        printDistribution(alpha76, alpha77)

        print("")
        print("ALPHA 7.7 – RECENCY 50 / TOP 2")
        print("----------------------------------------------")
        

        let totalTickets = evaluatedDraws * recommendationCount

        print("")
        print("==============================================")
        print("Ausgewertete Ziehungen : \(evaluatedDraws)")
        print("Gesamte Tipps         : \(totalTickets)")
        print("")
        print("DURCHSCHNITT")
        print("==============================================")
        print(String(
            format: "Alpha 7.6 Hauptzahlen : %.3f",
            Double(totalMain76) / Double(totalTickets)
        ))
        print(String(
            format: "Alpha 7.6 Eurozahlen : %.3f",
            Double(totalEuro76) / Double(totalTickets)
        ))
        print(String(
            format: "Alpha 7.7 Hauptzahlen : %.3f",
            Double(totalMain77) / Double(totalTickets)
        ))
        print(String(
            format: "Alpha 7.7 Eurozahlen : %.3f",
            Double(totalEuro77) / Double(totalTickets)
        ))
        print("==============================================")
    }

    private func printDistribution(
        _ alpha76: [[Int]],
        _ alpha77: [[Int]]
    ) {
        print("Treffer   | Alpha 7.6 | Alpha 7.7 | Differenz")
        print("----------------------------------------------")

        for main in 0...5 {
            for euro in 0...2 {
                let a76 = alpha76[main][euro]
                let a77 = alpha77[main][euro]
                let diff = a77 - a76

                print(
                    String(
                        format: "%d-%d       | %8d | %8d | %+8d",
                        main,
                        euro,
                        a76,
                        a77,
                        diff
                    )
                )
            }
        }
    }

    private func recency50TopTwo(
        draws: [EuroJackpotDraw]
    ) -> [Int] {
        let window = 50
        guard draws.count >= window else {
            return []
        }

        let recentDraws = draws.suffix(window)
        var frequencies: [Int: Int] = [:]

        for draw in recentDraws {
            for number in draw.euroNumbers {
                frequencies[number, default: 0] += 1
            }
        }

        let ranked = frequencies.keys.sorted {
            let lhs = frequencies[$0] ?? 0
            let rhs = frequencies[$1] ?? 0

            if lhs == rhs {
                return $0 < $1
            }

            return lhs > rhs
        }

        return Array(ranked.prefix(2))
    }
}
