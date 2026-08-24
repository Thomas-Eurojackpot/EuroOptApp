import Foundation

struct NineTipHitDistributionDiagnostic {

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
        print("🔬 9-TIPP TREFFERKLASSEN-HOLDOUT")
        print("==============================================")
        print("Holdout              : letzte \(holdoutCount) Ziehungen")
        print("Empfehlungen         : \(recommendationCount)")
        print("Alpha 7.6            : Original")
        print("Alpha 7.7            : Recency 50 / Top 2")
        print("----------------------------------------------")

        for index in holdoutStart..<draws.count {
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
        printDistribution(alpha76)

        print("")
        print("ALPHA 7.7 – RECENCY 50 / TOP 2")
        print("----------------------------------------------")
        printDistribution(alpha77)

        let totalTickets = holdoutCount * recommendationCount

        print("")
        print("==============================================")
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

    private func printDistribution(_ distribution: [[Int]]) {
        print("Haupt \\ Euro | 0        1        2")
        print("----------------------------------------------")

        for main in 0...5 {
            print(
                String(
                    format: "%5d        | %8d %8d %8d",
                    main,
                    distribution[main][0],
                    distribution[main][1],
                    distribution[main][2]
                )
            )
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
