import Foundation

struct ConcentrationWeightDiagnostic {

    private let variants: [(name: String, alpha: Double, concentration: Double)] = [
        ("A100", 1.00, 0.00),
        ("A80C20", 0.80, 0.20),
        ("A70C30", 0.70, 0.30),
        ("A60C40", 0.60, 0.40),
        ("C100", 0.00, 1.00)
    ]

    func run(
        draws: [EuroJackpotDraw],
        recommendationCount: Int,
        splitCount: Int = 10
    ) {
        let holdoutSize = 40
        let minimumTrainingSize = 300

        guard draws.count > minimumTrainingSize + holdoutSize else {
            print("❌ Konzentrationsvergleich: zu wenige Ziehungen")
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

        var totals = variants.map {
            (
                name: $0.name,
                main: 0.0,
                euro: 0.0,
                score: 0.0,
                wins: 0
            )
        }

        print("")
        print("===================================")
        print("🧪 ALPHA / KONZENTRATION – ABLATION")
        print("===================================")
        print("Splits              : \(splitCount)")
        print("Holdout je Split    : \(holdoutSize)")
        print("Kandidaten je Test  : \(candidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("⚡ Kandidaten/Scores werden je Holdout nur einmal berechnet.")
        print("")

        for split in 0..<splitCount {

            let holdoutStart: Int

            if splitCount == 1 {
                holdoutStart = firstHoldoutStart
            } else {
                holdoutStart = firstHoldoutStart
                    + Int(
                        (Double(split) / Double(splitCount - 1))
                        * Double(availableRange)
                    )
            }

            let holdoutEnd = holdoutStart + holdoutSize

            var splitTotals = variants.map {
                (
                    name: $0.name,
                    main: 0,
                    euro: 0,
                    tickets: 0
                )
            }

            for index in holdoutStart..<holdoutEnd {

                let targetDraw = draws[index]
                let trainingDraws = Array(draws.prefix(index))

                // -------------------------------------------------
                // 1. Kandidaten EINMAL erzeugen
                // -------------------------------------------------

                let candidates = generator.generate(
                    count: candidateCount,
                    draws: trainingDraws,
                    goal: OptimizationGoal(),
                    hillClimbingIterations: 0
                )

                // -------------------------------------------------
                // 2. Alpha EINMAL berechnen
                // -------------------------------------------------

                let scoreEngine = ScoreEngine(
                    goal: OptimizationGoal()
                )

                let alphaScores = candidates.map {
                    scoreEngine.score(
                        ticket: $0,
                        draws: trainingDraws
                    )
                }

                // -------------------------------------------------
                // 3. Konzentration EINMAL berechnen
                // -------------------------------------------------

                let concentration = concentrationScores(
                    candidates: candidates,
                    draws: trainingDraws
                )

                // -------------------------------------------------
                // 4. Beide Werte EINMAL normalisieren
                // -------------------------------------------------

                let normalizedAlpha = normalize(alphaScores)
                let normalizedConcentration = normalize(concentration)

                // -------------------------------------------------
                // 5. Jetzt nur noch die fünf Gewichtungen testen
                // -------------------------------------------------

                for variantIndex in variants.indices {

                    let variant = variants[variantIndex]

                    let rankedIndices = candidates.indices.sorted {
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

                    for candidateIndex in rankedIndices.prefix(
                        min(36, rankedIndices.count)
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

                        splitTotals[variantIndex].main +=
                            Set(ticket.numbers)
                                .intersection(targetDraw.numbers)
                                .count

                        splitTotals[variantIndex].euro +=
                            Set(ticket.euroNumbers)
                                .intersection(targetDraw.euroNumbers)
                                .count
                    }

                    splitTotals[variantIndex].tickets +=
                        selected.count
                }
            }

            // -----------------------------------------------------
            // Split-Auswertung
            // -----------------------------------------------------

            var splitResults: [
                (
                    name: String,
                    main: Double,
                    euro: Double,
                    score: Double
                )
            ] = []

            for result in splitTotals {

                let main = result.tickets > 0
                    ? Double(result.main) / Double(result.tickets)
                    : 0

                let euro = result.tickets > 0
                    ? Double(result.euro) / Double(result.tickets)
                    : 0

                let score =
                    (main - 0.50)
                    + (euro - 0.333333)

                splitResults.append(
                    (
                        name: result.name,
                        main: main,
                        euro: euro,
                        score: score
                    )
                )
            }

            if let winner = splitResults.max(
                by: { $0.score < $1.score }
            ) {
                if let index = totals.firstIndex(
                    where: { $0.name == winner.name }
                ) {
                    totals[index].wins += 1
                }
            }

            for result in splitResults {

                if let index = totals.firstIndex(
                    where: { $0.name == result.name }
                ) {
                    totals[index].main += result.main
                    totals[index].euro += result.euro
                    totals[index].score += result.score
                }
            }

            print("")
            print("SPLIT \(split + 1)")
            print("-----------------------------------")
            print(
                "Holdout: Ziehungen \(holdoutStart + 1)–\(holdoutEnd)"
            )

            for result in splitResults {

                print(
                    String(
                        format:
                            "%@  Haupt %.3f  Euro %.3f  Score %+.3f",
                        result.name,
                        result.main,
                        result.euro,
                        result.score
                    )
                )
            }
        }

        // ---------------------------------------------------------
        // Gesamtergebnis
        // ---------------------------------------------------------

        print("")
        print("===================================")
        print("GESAMTERGEBNIS")
        print("===================================")

        for variant in totals {

            let averageMain =
                variant.main / Double(splitCount)

            let averageEuro =
                variant.euro / Double(splitCount)

            let averageScore =
                variant.score / Double(splitCount)

            print(
                String(
                    format:
                        "%@  Siege %2d/%d | Haupt %.3f | Euro %.3f | Score %+.3f",
                    variant.name,
                    variant.wins,
                    splitCount,
                    averageMain,
                    averageEuro,
                    averageScore
                )
            )
        }

        if let winner = totals.max(
            by: {
                if $0.wins == $1.wins {
                    return $0.score < $1.score
                }

                return $0.wins < $1.wins
            }
        ) {
            print("")
            print("🥇 Häufigster Sieger: \(winner.name)")
            print("   Siege: \(winner.wins)/\(splitCount)")
        }

        print(
            String(
                format:
                    "⏱ Konzentrations-Ablation: %.2f Sekunden",
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
                            count
                                + (
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
