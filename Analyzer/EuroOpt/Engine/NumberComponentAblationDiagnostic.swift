import Foundation

struct NumberComponentAblationDiagnostic {

    private struct Profile {
        let name: String
        let goal: OptimizationGoal
        let useQuickScore: Bool
    }

    func run(
        draws: [EuroJackpotDraw],
        recommendationCount: Int,
        runCount: Int = 10
    ) {
        guard !draws.isEmpty else {
            print("❌ Komponenten-Ablation: keine Ziehungen vorhanden")
            return
        }

        let start = Date()

        let profiles = [
            Profile(
                name: "FULL",
                goal: OptimizationGoal(
                    frequencyWeight: 30,
                    pairWeight: 25,
                    evenOddWeight: 15,
                    highLowWeight: 15,
                    sumWeight: 15,
                    gapWeight: 0
                ),
                useQuickScore: true
            ),
            Profile(
                name: "NO-FREQUENCY",
                goal: OptimizationGoal(
                    frequencyWeight: 0,
                    pairWeight: 25,
                    evenOddWeight: 15,
                    highLowWeight: 15,
                    sumWeight: 15,
                    gapWeight: 0
                ),
                useQuickScore: true
            ),
            Profile(
                name: "NO-PAIR",
                goal: OptimizationGoal(
                    frequencyWeight: 30,
                    pairWeight: 0,
                    evenOddWeight: 15,
                    highLowWeight: 15,
                    sumWeight: 15,
                    gapWeight: 0
                ),
                useQuickScore: true
            ),
            Profile(
                name: "NO-FREQ-NO-PAIR",
                goal: OptimizationGoal(
                    frequencyWeight: 0,
                    pairWeight: 0,
                    evenOddWeight: 15,
                    highLowWeight: 15,
                    sumWeight: 15,
                    gapWeight: 0
                ),
                useQuickScore: false
            )
        ]

        let candidateCount = max(
            AppSettings.backtestCandidateCount + 1,
            301
        )

        print("")
        print("===================================")
        print("🔬 ALPHA 7.6 SCORE-KOMPONENTEN-ABLATION")
        print("===================================")
        print("Läufe              : \(runCount)")
        print("Empfehlungen/Lauf  : \(recommendationCount)")
        print("Kandidaten/Lauf    : \(candidateCount)")
        print("")

        for profile in profiles {

            var frequencies = Array(
                repeating: 0,
                count: 51
            )

            for _ in 0..<runCount {

                let candidates = TicketGenerator().generate(
                    count: candidateCount,
                    draws: draws,
                    goal: profile.goal,
                    hillClimbingIterations: AppSettings.hillClimbingIterations,
                    useQuickScore: profile.useQuickScore
                )

                let ranked = OptimizerEngine()
                    .rankedTicketsForDiagnostic(
                        from: candidates,
                        draws: draws
                    )

                let pool = Array(
                    ranked.prefix(min(36, ranked.count))
                )

                let selected = select(
                    pool: pool,
                    limit: recommendationCount
                )

                for ticket in selected {
                    for number in ticket.numbers {
                        frequencies[number] += 1
                    }
                }
            }

            print("-----------------------------------")
            print(profile.name)
            print("-----------------------------------")

            if !profile.useQuickScore {
                print("⚠️ QuickScore deaktiviert")
                print("")
            }

            let top = (1...50)
                .sorted {
                    frequencies[$0] > frequencies[$1]
                }
                .prefix(10)

            for number in top {
                print(
                    String(
                        format: "%2d: %3dx",
                        number,
                        frequencies[number]
                    )
                )
            }

            print("")
            print(
                "34=\(frequencies[34]) | " +
                "21=\(frequencies[21]) | " +
                "30=\(frequencies[30]) | " +
                "20=\(frequencies[20]) | " +
                "17=\(frequencies[17])"
            )
            print("")
        }

        print("===================================")
        print(
            String(
                format:
                    "⏱ Komponenten-Ablation: %.2f Sekunden",
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
