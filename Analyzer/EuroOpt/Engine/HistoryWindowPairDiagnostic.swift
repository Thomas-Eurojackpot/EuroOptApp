import Foundation

struct HistoryWindowPairDiagnostic {

    func run(
        draws: [EuroJackpotDraw],
        recommendationCount: Int,
        splitCount: Int = 10
    ) {
        let holdoutSize = 40

        guard draws.count > holdoutSize + 100 else {
            print("❌ History-Window-Paarvergleich: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let generator = TicketGenerator()
        let candidateCount = max(AppSettings.backtestCandidateCount + 1, 301)

        var w150Wins = 0
        var w300Wins = 0
        var ties = 0

        var total150Main = 0.0
        var total150Euro = 0.0
        var total300Main = 0.0
        var total300Euro = 0.0

        print("")
        print("===================================")
        print("🧪 W150 vs. W300 – PAARVERGLEICH")
        print("===================================")
        print("Splits              : \(splitCount)")
        print("Holdout je Split    : \(holdoutSize)")
        print("Kandidaten je Test  : \(candidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("")

        let minimumTrainingSize = 300
        let firstHoldoutStart = minimumTrainingSize
        let lastHoldoutStart = draws.count - holdoutSize

        guard lastHoldoutStart >= firstHoldoutStart else {
            print("❌ Nicht genügend Ziehungen für 10 zeitlich verteilte Splits")
            return
        }

        let availableStartRange = lastHoldoutStart - firstHoldoutStart

        for split in 0..<splitCount {

            let holdoutStart: Int

            if splitCount == 1 {
                holdoutStart = firstHoldoutStart
            } else {
                holdoutStart = firstHoldoutStart
                    + Int(
                        (Double(split) / Double(splitCount - 1))
                        * Double(availableStartRange)
                    )
            }

            let holdoutEnd = holdoutStart + holdoutSize

            var w150Main = 0
            var w150Euro = 0
            var w150Tickets = 0

            var w300Main = 0
            var w300Euro = 0
            var w300Tickets = 0

            for index in holdoutStart..<holdoutEnd {

                let targetDraw = draws[index]
                let availableTraining = Array(draws.prefix(index))

                let training150 = Array(
                    availableTraining.suffix(
                        min(150, availableTraining.count)
                    )
                )

                let training300 = Array(
                    availableTraining.suffix(
                        min(300, availableTraining.count)
                    )
                )

                let candidates150 = generator.generate(
                    count: candidateCount,
                    draws: training150,
                    goal: OptimizationGoal(),
                    hillClimbingIterations: 0
                )

                let ranked150 = OptimizerEngine()
                    .rankedTicketsForDiagnostic(
                        from: candidates150,
                        draws: training150
                    )

                let selected150 = select(
                    pool: Array(ranked150.prefix(min(36, ranked150.count))),
                    limit: recommendationCount
                )

                for ticket in selected150 {
                    w150Main += Set(ticket.numbers)
                        .intersection(targetDraw.numbers)
                        .count

                    w150Euro += Set(ticket.euroNumbers)
                        .intersection(targetDraw.euroNumbers)
                        .count
                }

                w150Tickets += selected150.count

                let candidates300 = generator.generate(
                    count: candidateCount,
                    draws: training300,
                    goal: OptimizationGoal(),
                    hillClimbingIterations: 0
                )

                let ranked300 = OptimizerEngine()
                    .rankedTicketsForDiagnostic(
                        from: candidates300,
                        draws: training300
                    )

                let selected300 = select(
                    pool: Array(ranked300.prefix(min(36, ranked300.count))),
                    limit: recommendationCount
                )

                for ticket in selected300 {
                    w300Main += Set(ticket.numbers)
                        .intersection(targetDraw.numbers)
                        .count

                    w300Euro += Set(ticket.euroNumbers)
                        .intersection(targetDraw.euroNumbers)
                        .count
                }

                w300Tickets += selected300.count
            }

            let main150 = w150Tickets > 0
                ? Double(w150Main) / Double(w150Tickets)
                : 0

            let euro150 = w150Tickets > 0
                ? Double(w150Euro) / Double(w150Tickets)
                : 0

            let main300 = w300Tickets > 0
                ? Double(w300Main) / Double(w300Tickets)
                : 0

            let euro300 = w300Tickets > 0
                ? Double(w300Euro) / Double(w300Tickets)
                : 0

            let score150 =
                (main150 - 0.50) +
                (euro150 - 0.333333)

            let score300 =
                (main300 - 0.50) +
                (euro300 - 0.333333)

            let deltaMain = main150 - main300
            let deltaEuro = euro150 - euro300
            let deltaScore = score150 - score300

            if deltaScore > 0 {
                w150Wins += 1
            } else if deltaScore < 0 {
                w300Wins += 1
            } else {
                ties += 1
            }

            total150Main += main150
            total150Euro += euro150
            total300Main += main300
            total300Euro += euro300

            print("")
            print("SPLIT \(split + 1)")
            print("-----------------------------------")
            print("Holdout: Ziehungen \(holdoutStart + 1)–\(holdoutEnd)")
            print(String(format: "W150  Haupt %.3f  Euro %.3f  Score %+.3f",
                         main150, euro150, score150))
            print(String(format: "W300  Haupt %.3f  Euro %.3f  Score %+.3f",
                         main300, euro300, score300))
            print(String(format: "Δ W150-W300  Haupt %+.3f  Euro %+.3f  Score %+.3f",
                         deltaMain, deltaEuro, deltaScore))
        }

        let actualSplits = w150Wins + w300Wins + ties

        guard actualSplits > 0 else {
            print("❌ Keine verwertbaren Splits")
            return
        }

        print("")
        print("===================================")
        print("GESAMTERGEBNIS W150 vs. W300")
        print("===================================")
        print("W150 Siege        : \(w150Wins)/\(actualSplits)")
        print("W300 Siege        : \(w300Wins)/\(actualSplits)")
        print("Unentschieden     : \(ties)/\(actualSplits)")

        print("")
        print(String(
            format: "W150 Ø Haupt     : %.3f",
            total150Main / Double(actualSplits)
        ))
        print(String(
            format: "W150 Ø Euro      : %.3f",
            total150Euro / Double(actualSplits)
        ))

        print(String(
            format: "W300 Ø Haupt     : %.3f",
            total300Main / Double(actualSplits)
        ))
        print(String(
            format: "W300 Ø Euro      : %.3f",
            total300Euro / Double(actualSplits)
        ))

        print(String(
            format: "Ø Δ Haupt        : %+.3f",
            (total150Main - total300Main) / Double(actualSplits)
        ))

        print(String(
            format: "Ø Δ Euro         : %+.3f",
            (total150Euro - total300Euro) / Double(actualSplits)
        ))

        print(String(
            format: "⏱ Paarvergleich   : %.2f Sekunden",
            Date().timeIntervalSince(start)
        ))

        print("===================================")
    }

    private func select(
        pool: [(ticket: Ticket, score: Double)],
        limit: Int
    ) -> [Ticket] {

        var selected: [Ticket] = []

        for item in pool {
            if selected.allSatisfy({
                commonNumbers($0, item.ticket) < 3
            }) {
                selected.append(item.ticket)
            }

            if selected.count == limit {
                break
            }
        }

        return selected
    }

    private func commonNumbers(
        _ lhs: Ticket,
        _ rhs: Ticket
    ) -> Int {
        Set(lhs.numbers)
            .intersection(rhs.numbers)
            .count
    }
}
