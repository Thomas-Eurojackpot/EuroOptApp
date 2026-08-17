import Foundation

struct HistoryWindowRobustnessDiagnostic {

    private let windows: [(name: String, size: Int?)] = [
        ("FULL", nil),
        ("W300", 300),
        ("W200", 200),
        ("W150", 150),
        ("W100", 100)
    ]

    func run(
        draws: [EuroJackpotDraw],
        recommendationCount: Int,
        splitCount: Int = 5
    ) {
        let holdoutSize = 100

        guard draws.count > holdoutSize + 100 else {
            print("❌ History-Window-Robustheit: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let generator = TicketGenerator()
        let candidateCount = max(AppSettings.backtestCandidateCount + 1, 301)

        print("")
        print("===================================")
        print("🧪 HISTORY-WINDOW ROBUSTHEIT")
        print("===================================")
        print("Splits              : \(splitCount)")
        print("Holdout je Split    : \(holdoutSize)")
        print("Kandidaten je Test  : \(candidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("Fenster             : FULL / W300 / W200 / W150 / W100")
        print("")

        var wins: [String: Int] = [:]
        var sumMain: [String: Double] = [:]
        var sumEuro: [String: Double] = [:]
        var sumCombined: [String: Double] = [:]

        for split in 0..<splitCount {

            let holdoutEnd = draws.count - split * holdoutSize
            let holdoutStart = holdoutEnd - holdoutSize

            guard holdoutStart > 100 else { break }

            print("-----------------------------------")
            print("SPLIT \(split + 1)")
            print("Training bis       : \(holdoutStart - 1)")
            print("Holdout             : \(holdoutStart) ... \(holdoutEnd - 1)")
            print("-----------------------------------")

            var splitResults: [(name: String, main: Double, euro: Double, combined: Double)] = []

            for window in windows {

                var totalMain = 0
                var totalEuro = 0
                var totalTickets = 0

                for index in holdoutStart..<holdoutEnd {

                    let targetDraw = draws[index]
                    let availableTraining = Array(draws.prefix(index))

                    let trainingDraws: [EuroJackpotDraw]

                    if let size = window.size {
                        trainingDraws = Array(
                            availableTraining.suffix(
                                min(size, availableTraining.count)
                            )
                        )
                    } else {
                        trainingDraws = availableTraining
                    }

                    let candidates = generator.generate(
                        count: candidateCount,
                        draws: trainingDraws,
                        goal: OptimizationGoal(),
                        hillClimbingIterations: 0
                    )

                    let rankingEngine = OptimizerEngine()

                    let ranked = rankingEngine.rankedTicketsForDiagnostic(
                        from: candidates,
                        draws: trainingDraws
                    )

                    let pool = Array(
                        ranked.prefix(min(36, ranked.count))
                    )

                    let selected = select(
                        pool: pool,
                        limit: recommendationCount
                    )

                    for ticket in selected {
                        totalMain += Set(ticket.numbers)
                            .intersection(targetDraw.numbers)
                            .count

                        totalEuro += Set(ticket.euroNumbers)
                            .intersection(targetDraw.euroNumbers)
                            .count
                    }

                    totalTickets += selected.count
                }

                let main = totalTickets > 0
                    ? Double(totalMain) / Double(totalTickets)
                    : 0

                let euro = totalTickets > 0
                    ? Double(totalEuro) / Double(totalTickets)
                    : 0

                let combined =
                    (main - 0.50) +
                    (euro - 0.333333)

                splitResults.append(
                    (
                        name: window.name,
                        main: main,
                        euro: euro,
                        combined: combined
                    )
                )

                print(
                    String(
                        format: "%@  Haupt %.3f  Euro %.3f  Score %+.3f",
                        window.name,
                        main,
                        euro,
                        combined
                    )
                )
            }

            guard let winner = splitResults.max(
                by: { $0.combined < $1.combined }
            ) else {
                continue
            }

            wins[winner.name, default: 0] += 1
            sumMain[winner.name, default: 0] += winner.main
            sumEuro[winner.name, default: 0] += winner.euro
            sumCombined[winner.name, default: 0] += winner.combined

            print("🏆 Split-Sieger: \(winner.name)")
        }

        print("")
        print("===================================")
        print("GESAMT – HISTORY-WINDOW ROBUSTHEIT")
        print("===================================")

        for window in windows {

            let name = window.name
            let winCount = wins[name, default: 0]

            print(
                String(
                    format: "%@  Siege %d/%d",
                    name,
                    winCount,
                    splitCount
                )
            )

            if winCount > 0 {
                print(
                    String(
                        format: "     Ø Haupt %.3f | Ø Euro %.3f | Ø Score %+.3f",
                        sumMain[name]! / Double(winCount),
                        sumEuro[name]! / Double(winCount),
                        sumCombined[name]! / Double(winCount)
                    )
                )
            }
        }

        print("-----------------------------------")

        if let best = windows.max(
            by: {
                wins[$0.name, default: 0] <
                wins[$1.name, default: 0]
            }
        ) {
            print(
                "🥇 Häufigster Split-Sieger: \(best.name)"
            )
            print(
                "   Siege: \(wins[best.name, default: 0])/\(splitCount)"
            )
        }

        print(
            String(
                format: "⏱ History-Window-Robustheit: %.2f Sekunden",
                Date().timeIntervalSince(start)
            )
        )

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
