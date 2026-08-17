import Foundation

struct ConcentrationPairDiagnostic {

    private let variants: [(name: String, alpha: Double, concentration: Double)] = [
        ("A70C30", 0.70, 0.30),
        ("A60C40", 0.60, 0.40)
    ]

    func run(
        draws: [EuroJackpotDraw],
        recommendationCount: Int,
        splitCount: Int = 10
    ) {
        let holdoutSize = 40
        let minimumTrainingSize = 300

        guard draws.count > minimumTrainingSize + holdoutSize else {
            print("❌ Konzentrations-Paarvergleich: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let candidateCount = max(
            AppSettings.backtestCandidateCount + 1,
            301
        )

        let generator = TicketGenerator()

        let firstHoldoutStart = minimumTrainingSize
        let lastHoldoutStart = draws.count - holdoutSize
        let availableRange = lastHoldoutStart - firstHoldoutStart

        var wins70 = 0
        var wins60 = 0
        var ties = 0

        var total70Main = 0.0
        var total70Euro = 0.0
        var total60Main = 0.0
        var total60Euro = 0.0

        print("")
        print("===================================")
        print("🧪 A70C30 vs. A60C40")
        print("===================================")
        print("Splits              : \(splitCount)")
        print("Holdout je Split    : \(holdoutSize)")
        print("Kandidaten je Test  : \(candidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("")

        for split in 0..<splitCount {

            let holdoutStart = splitCount == 1
                ? firstHoldoutStart
                : firstHoldoutStart
                    + Int(
                        (Double(split) / Double(splitCount - 1))
                        * Double(availableRange)
                    )

            let holdoutEnd = holdoutStart + holdoutSize

            var splitResults: [
                (name: String, main: Double, euro: Double, score: Double)
            ] = []

            for variant in variants {

                var totalMain = 0
                var totalEuro = 0
                var totalTickets = 0

                for index in holdoutStart..<holdoutEnd {

                    let targetDraw = draws[index]
                    let trainingDraws = Array(draws.prefix(index))

                    let candidates = generator.generate(
                        count: candidateCount,
                        draws: trainingDraws,
                        goal: OptimizationGoal(),
                        hillClimbingIterations: 0
                    )

                    let scoreEngine = ScoreEngine(
                        goal: OptimizationGoal()
                    )

                    let alphaScores = candidates.map {
                        scoreEngine.score(
                            ticket: $0,
                            draws: trainingDraws
                        )
                    }

                    let concentration = concentrationScores(
                        candidates: candidates,
                        draws: trainingDraws
                    )

                    let normalizedAlpha = normalize(alphaScores)
                    let normalizedConcentration = normalize(concentration)

                    let ranked = candidates.indices.sorted {
                        let lhs =
                            variant.alpha * normalizedAlpha[$0]
                            + variant.concentration
                            * normalizedConcentration[$0]

                        let rhs =
                            variant.alpha * normalizedAlpha[$1]
                            + variant.concentration
                            * normalizedConcentration[$1]

                        if lhs == rhs {
                            return $0 < $1
                        }

                        return lhs > rhs
                    }

                    var selected: [Ticket] = []

                    for candidateIndex in ranked.prefix(
                        min(36, ranked.count)
                    ) {
                        let ticket = candidates[candidateIndex]

                        if selected.allSatisfy({
                            commonNumbers($0, ticket) < 3
                        }) {
                            selected.append(ticket)
                        }

                        if selected.count == recommendationCount {
                            break
                        }
                    }

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

                let score =
                    (main - 0.50)
                    + (euro - 0.333333)

                splitResults.append(
                    (
                        name: variant.name,
                        main: main,
                        euro: euro,
                        score: score
                    )
                )
            }

            guard splitResults.count == 2 else {
                continue
            }

            let a70 = splitResults[0]
            let a60 = splitResults[1]

            let deltaMain = a60.main - a70.main
            let deltaEuro = a60.euro - a70.euro
            let deltaScore = a60.score - a70.score

            if deltaScore > 0 {
                wins60 += 1
            } else if deltaScore < 0 {
                wins70 += 1
            } else {
                ties += 1
            }

            total70Main += a70.main
            total70Euro += a70.euro
            total60Main += a60.main
            total60Euro += a60.euro

            print("")
            print("SPLIT \(split + 1)")
            print("-----------------------------------")
            print("Holdout: Ziehungen \(holdoutStart + 1)–\(holdoutEnd)")

            print(
                String(
                    format:
                        "A70C30  Haupt %.3f  Euro %.3f  Score %+.3f",
                    a70.main,
                    a70.euro,
                    a70.score
                )
            )

            print(
                String(
                    format:
                        "A60C40  Haupt %.3f  Euro %.3f  Score %+.3f",
                    a60.main,
                    a60.euro,
                    a60.score
                )
            )

            print(
                String(
                    format:
                        "Δ A60-A70  Haupt %+.3f  Euro %+.3f  Score %+.3f",
                    deltaMain,
                    deltaEuro,
                    deltaScore
                )
            )
        }

        print("")
        print("===================================")
        print("GESAMTERGEBNIS A70C30 vs. A60C40")
        print("===================================")
        print("A70C30 Siege       : \(wins70)/\(splitCount)")
        print("A60C40 Siege       : \(wins60)/\(splitCount)")
        print("Unentschieden      : \(ties)/\(splitCount)")

        let divisor = Double(splitCount)

        let avg70Main = total70Main / divisor
        let avg70Euro = total70Euro / divisor
        let avg60Main = total60Main / divisor
        let avg60Euro = total60Euro / divisor

        print(String(format: "A70C30 Ø Haupt     : %.3f", avg70Main))
        print(String(format: "A70C30 Ø Euro      : %.3f", avg70Euro))
        print(String(format: "A60C40 Ø Haupt     : %.3f", avg60Main))
        print(String(format: "A60C40 Ø Euro      : %.3f", avg60Euro))

        print(
            String(
                format: "Ø Δ Haupt         : %+.3f",
                avg60Main - avg70Main
            )
        )

        print(
            String(
                format: "Ø Δ Euro          : %+.3f",
                avg60Euro - avg70Euro
            )
        )

        print(
            String(
                format:
                    "Ø Δ kombiniert    : %+.3f",
                (avg60Main - avg70Main)
                    + (avg60Euro - avg70Euro)
            )
        )

        print(
            String(
                format:
                    "⏱ Konzentrations-Paarvergleich: %.2f Sekunden",
                Date().timeIntervalSince(start)
            )
        )

        print("===================================")
    }

    private func concentrationScores(
        candidates: [Ticket],
        draws: [EuroJackpotDraw]
    ) -> [Double] {

        let counts = Dictionary(
            uniqueKeysWithValues:
                (1...50).map { number in
                    (
                        number,
                        draws.reduce(0) { count, draw in
                            count + (
                                draw.numbers.contains(number)
                                ? 1
                                : 0
                            )
                        }
                    )
                }
        )

        let ranked = (1...50).sorted {
            if counts[$0, default: 0]
                == counts[$1, default: 0] {
                return $0 < $1
            }

            return counts[$0, default: 0]
                > counts[$1, default: 0]
        }

        let denominator =
            Double(max(1, ranked.count - 1))

        let rankMap = Dictionary(
            uniqueKeysWithValues:
                ranked.enumerated().map {
                    (
                        $0.element,
                        1.0
                            - Double($0.offset)
                            / denominator
                    )
                }
        )

        return candidates.map { ticket in

            let ranks = ticket.numbers
                .map {
                    rankMap[$0, default: 0]
                }
                .sorted(by: >)

            guard ranks.count == 5 else {
                return 0
            }

            return ranks[0] * 0.35
                + ranks[1] * 0.25
                + ranks[2] * 0.20
                + ranks[3] * 0.12
                + ranks[4] * 0.08
        }
    }

    private func normalize(
        _ values: [Double]
    ) -> [Double] {

        guard let minValue = values.min(),
              let maxValue = values.max(),
              maxValue > minValue else {
            return values.map { _ in 0.5 }
        }

        return values.map {
            ($0 - minValue)
                / (maxValue - minValue)
        }
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
