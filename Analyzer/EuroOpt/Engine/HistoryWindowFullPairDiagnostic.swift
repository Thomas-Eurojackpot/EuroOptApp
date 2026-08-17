import Foundation

struct HistoryWindowFullPairDiagnostic {

    func run(
        draws: [EuroJackpotDraw],
        recommendationCount: Int,
        splitCount: Int = 10
    ) {
        let holdoutSize = 40
        let minimumTrainingSize = 300

        guard draws.count > minimumTrainingSize + holdoutSize else {
            print("❌ FULL/W300-Paarvergleich: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let generator = TicketGenerator()
        let candidateCount = max(AppSettings.backtestCandidateCount + 1, 301)

        let firstHoldoutStart = minimumTrainingSize
        let lastHoldoutStart = draws.count - holdoutSize
        let availableStartRange = lastHoldoutStart - firstHoldoutStart

        var fullWins = 0
        var w300Wins = 0
        var ties = 0

        var totalFullMain = 0.0
        var totalFullEuro = 0.0
        var totalW300Main = 0.0
        var totalW300Euro = 0.0

        print("")
        print("===================================")
        print("🧪 FULL vs. W300 – PAARVERGLEICH")
        print("===================================")
        print("Splits              : \(splitCount)")
        print("Holdout je Split    : \(holdoutSize)")
        print("Kandidaten je Test  : \(candidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("")

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

            var fullMain = 0
            var fullEuro = 0
            var fullTickets = 0

            var w300Main = 0
            var w300Euro = 0
            var w300Tickets = 0

            for index in holdoutStart..<holdoutEnd {

                let targetDraw = draws[index]
                let availableTraining = Array(draws.prefix(index))

                let fullTraining = availableTraining

                let w300Training = Array(
                    availableTraining.suffix(
                        min(300, availableTraining.count)
                    )
                )

                let fullCandidates = generator.generate(
                    count: candidateCount,
                    draws: fullTraining,
                    goal: OptimizationGoal(),
                    hillClimbingIterations: 0
                )

                let fullRanked = OptimizerEngine()
                    .rankedTicketsForDiagnostic(
                        from: fullCandidates,
                        draws: fullTraining
                    )

                let fullSelected = select(
                    pool: Array(fullRanked.prefix(min(36, fullRanked.count))),
                    limit: recommendationCount
                )

                for ticket in fullSelected {
                    fullMain += Set(ticket.numbers)
                        .intersection(targetDraw.numbers)
                        .count

                    fullEuro += Set(ticket.euroNumbers)
                        .intersection(targetDraw.euroNumbers)
                        .count
                }

                fullTickets += fullSelected.count

                let w300Candidates = generator.generate(
                    count: candidateCount,
                    draws: w300Training,
                    goal: OptimizationGoal(),
                    hillClimbingIterations: 0
                )

                let w300Ranked = OptimizerEngine()
                    .rankedTicketsForDiagnostic(
                        from: w300Candidates,
                        draws: w300Training
                    )

                let w300Selected = select(
                    pool: Array(w300Ranked.prefix(min(36, w300Ranked.count))),
                    limit: recommendationCount
                )

                for ticket in w300Selected {
                    w300Main += Set(ticket.numbers)
                        .intersection(targetDraw.numbers)
                        .count

                    w300Euro += Set(ticket.euroNumbers)
                        .intersection(targetDraw.euroNumbers)
                        .count
                }

                w300Tickets += w300Selected.count
            }

            let fullMainAverage = fullTickets > 0
                ? Double(fullMain) / Double(fullTickets)
                : 0

            let fullEuroAverage = fullTickets > 0
                ? Double(fullEuro) / Double(fullTickets)
                : 0

            let w300MainAverage = w300Tickets > 0
                ? Double(w300Main) / Double(w300Tickets)
                : 0

            let w300EuroAverage = w300Tickets > 0
                ? Double(w300Euro) / Double(w300Tickets)
                : 0

            let fullScore =
                (fullMainAverage - 0.50)
                + (fullEuroAverage - 0.333333)

            let w300Score =
                (w300MainAverage - 0.50)
                + (w300EuroAverage - 0.333333)

            let deltaMain = w300MainAverage - fullMainAverage
            let deltaEuro = w300EuroAverage - fullEuroAverage
            let deltaScore = w300Score - fullScore

            if deltaScore > 0 {
                w300Wins += 1
            } else if deltaScore < 0 {
                fullWins += 1
            } else {
                ties += 1
            }

            totalFullMain += fullMainAverage
            totalFullEuro += fullEuroAverage
            totalW300Main += w300MainAverage
            totalW300Euro += w300EuroAverage

            print("")
            print("SPLIT \(split + 1)")
            print("-----------------------------------")
            print("Holdout: Ziehungen \(holdoutStart + 1)–\(holdoutEnd)")
            print(String(
                format: "FULL  Haupt %.3f  Euro %.3f  Score %+.3f",
                fullMainAverage,
                fullEuroAverage,
                fullScore
            ))
            print(String(
                format: "W300  Haupt %.3f  Euro %.3f  Score %+.3f",
                w300MainAverage,
                w300EuroAverage,
                w300Score
            ))
            print(String(
                format: "Δ W300-FULL  Haupt %+.3f  Euro %+.3f  Score %+.3f",
                deltaMain,
                deltaEuro,
                deltaScore
            ))
        }

        let actualSplits = fullWins + w300Wins + ties

        guard actualSplits > 0 else {
            print("❌ Keine verwertbaren Splits")
            return
        }

        print("")
        print("===================================")
        print("GESAMTERGEBNIS FULL vs. W300")
        print("===================================")
        print("FULL Siege        : \(fullWins)/\(actualSplits)")
        print("W300 Siege        : \(w300Wins)/\(actualSplits)")
        print("Unentschieden     : \(ties)/\(actualSplits)")

        print("")
        print(String(
            format: "FULL Ø Haupt     : %.3f",
            totalFullMain / Double(actualSplits)
        ))
        print(String(
            format: "FULL Ø Euro      : %.3f",
            totalFullEuro / Double(actualSplits)
        ))

        print(String(
            format: "W300 Ø Haupt     : %.3f",
            totalW300Main / Double(actualSplits)
        ))
        print(String(
            format: "W300 Ø Euro      : %.3f",
            totalW300Euro / Double(actualSplits)
        ))

        print(String(
            format: "Ø Δ Haupt        : %+.3f",
            (totalW300Main - totalFullMain) / Double(actualSplits)
        ))

        print(String(
            format: "Ø Δ Euro         : %+.3f",
            (totalW300Euro - totalFullEuro) / Double(actualSplits)
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
