import Foundation

struct NumberFrequencyDiagnostic {

    func run(
        draws: [EuroJackpotDraw],
        recommendationCount: Int,
        runCount: Int = 10
    ) {
        guard !draws.isEmpty else {
            print("❌ Number-Frequency-Test: keine Ziehungen vorhanden")
            return
        }

        let start = Date()
        let candidateCount = max(
            AppSettings.backtestCandidateCount + 1,
            301
        )

        let totalTickets = runCount * recommendationCount

        print("")
        print("===================================")
        print("🔬 ALPHA 7.6 ZAHLEN-FREQUENZ-KONTROLLE")
        print("===================================")
        print("Optimizer-Tickets : \(totalTickets)")
        print("Zufalls-Tickets   : \(totalTickets)")
        print("")

        var optimizerMain = Array(
            repeating: 0,
            count: 51
        )

        var optimizerEuro = Array(
            repeating: 0,
            count: 13
        )

        var randomMain = Array(
            repeating: 0,
            count: 51
        )

        var randomEuro = Array(
            repeating: 0,
            count: 13
        )

        // ---------------------------------------------------------
        // Optimizer
        // ---------------------------------------------------------

        for _ in 0..<runCount {

            let candidates = TicketGenerator().generate(
                count: candidateCount,
                draws: draws,
                goal: OptimizationGoal(),
                hillClimbingIterations: AppSettings.hillClimbingIterations
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
                    optimizerMain[number] += 1
                }

                for number in ticket.euroNumbers {
                    optimizerEuro[number] += 1
                }
            }
        }

        // ---------------------------------------------------------
        // Zufallskontrolle
        // ---------------------------------------------------------

        for _ in 0..<totalTickets {

            var numbers = Set<Int>()

            while numbers.count < 5 {
                numbers.insert(Int.random(in: 1...50))
            }

            var euroNumbers = Set<Int>()

            while euroNumbers.count < 2 {
                euroNumbers.insert(Int.random(in: 1...12))
            }

            for number in numbers {
                randomMain[number] += 1
            }

            for number in euroNumbers {
                randomEuro[number] += 1
            }
        }

        // ---------------------------------------------------------
        // Erwartungswerte
        // ---------------------------------------------------------

        let expectedMain =
            Double(totalTickets * 5) / 50.0

        let expectedEuro =
            Double(totalTickets * 2) / 12.0

        print("-----------------------------------")
        print("HAUPTZAHLEN")
        print("-----------------------------------")

        print(
            String(
                format:
                    "Erwartungswert je Zahl : %.2f",
                expectedMain
            )
        )

        print("")

        for number in 1...50 {

            let optimizer = optimizerMain[number]
            let random = randomMain[number]

            print(
                String(
                    format:
                        "%2d  Optimizer %3d | Zufall %3d | Δ %+3d",
                    number,
                    optimizer,
                    random,
                    optimizer - random
                )
            )
        }

        print("")
        print("-----------------------------------")
        print("EUROZAHLEN")
        print("-----------------------------------")

        print(
            String(
                format:
                    "Erwartungswert je Eurozahl : %.2f",
                expectedEuro
            )
        )

        print("")

        for number in 1...12 {

            let optimizer = optimizerEuro[number]
            let random = randomEuro[number]

            print(
                String(
                    format:
                        "%2d  Optimizer %3d | Zufall %3d | Δ %+3d",
                    number,
                    optimizer,
                    random,
                    optimizer - random
                )
            )
        }

        // ---------------------------------------------------------
        // Top-10 nach Abweichung vom Zufall
        // ---------------------------------------------------------

        let topMain = (1...50)
            .sorted {
                abs(optimizerMain[$0] - randomMain[$0])
                >
                abs(optimizerMain[$1] - randomMain[$1])
            }
            .prefix(10)

        print("")
        print("-----------------------------------")
        print("STÄRKSTE ABWEICHUNGEN VOM ZUFALL")
        print("-----------------------------------")

        for number in topMain {

            print(
                String(
                    format:
                        "%2d  Optimizer %3d | Zufall %3d | Δ %+3d",
                    number,
                    optimizerMain[number],
                    randomMain[number],
                    optimizerMain[number] - randomMain[number]
                )
            )
        }

        print("")
        print("===================================")
        print(
            String(
                format:
                    "⏱ Zahlen-Frequenz-Test: %.2f Sekunden",
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
