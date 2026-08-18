//
//  EuroRecency50ConfirmationDiagnostic.swift
//  EuroOpt
//
//  Bestätigung des festgelegten Recency-50 / Top-2 Signals
//

import Foundation

final class EuroRecency50ConfirmationDiagnostic {

    private let monteCarloRuns = 200
    private let window = 50
    private let selectionCount = 2

    func run(draws: [EuroJackpotDraw]) {

        guard draws.count >= 389 else {
            print("❌ Recency-50-Confirmation: zu wenige Ziehungen")
            return
        }

        let start = Date()

        // Der bisherige 290er-Holdout beginnt bei Index 389.
        // Daher werden ausschließlich frühere Ziehungen verwendet.
        let confirmationEnd = 389
        let minimumTraining = 100

        let available =
            confirmationEnd - minimumTraining

        let blockSize = available / 3

        let blocks: [(String, Int, Int)] = [
            (
                "Block 1",
                minimumTraining,
                minimumTraining + blockSize
            ),
            (
                "Block 2",
                minimumTraining + blockSize,
                minimumTraining + blockSize * 2
            ),
            (
                "Block 3",
                minimumTraining + blockSize * 2,
                confirmationEnd
            )
        ]

        print("")
        print("===================================")
        print("🎯 EURO-RECENCY 50 – BESTÄTIGUNG")
        print("===================================")
        print("Signal            : Recency 50")
        print("Auswahl           : Top 2")
        print("Bestätigungsdaten : vor bisherigem Holdout")
        print("Blöcke            : 3")
        print("Monte-Carlo       : \(monteCarloRuns)")
        print("")

        var allModelHits = 0
        var allRandomHits = 0
        var allTickets = 0

        var blockDeltas: [Double] = []

        for block in blocks {

            let modelAverage = evaluateModel(
                draws: draws,
                startIndex: block.1,
                endIndex: block.2
            )

            let randomAverages = evaluateRandom(
                draws: draws,
                startIndex: block.1,
                endIndex: block.2
            )

            let randomAverage = mean(randomAverages)

            let delta =
                modelAverage - randomAverage

            let confidenceInterval =
                pairedConfidenceInterval(
                    randomAverages.map {
                        modelAverage - $0
                    }
                )

            let modelHits =
                evaluateModelHits(
                    draws: draws,
                    startIndex: block.1,
                    endIndex: block.2
                )

            let randomHits =
                Int(
                    round(
                        randomAverage *
                        Double(block.2 - block.1)
                    )
                )

            let tickets =
                block.2 - block.1

            allModelHits += modelHits
            allRandomHits += randomHits
            allTickets += tickets

            blockDeltas.append(delta)

            print(
                String(
                    format:
                        "%@ | Modell %.4f | Zufall %.4f | Δ %+.4f | 95%% CI ±%.4f",
                    block.0,
                    modelAverage,
                    randomAverage,
                    delta,
                    confidenceInterval
                )
            )
        }

        let combinedModel =
            Double(allModelHits) /
            Double(allTickets)

        let combinedRandom =
            Double(allRandomHits) /
            Double(allTickets)

        let combinedDelta =
            combinedModel - combinedRandom

        print("")
        print("-----------------------------------")
        print("GESAMT")
        print("-----------------------------------")
        print(
            String(
                format:
                    "Modell %.4f | Zufall %.4f | Δ %+.4f",
                combinedModel,
                combinedRandom,
                combinedDelta
            )
        )

        print("")
        print("Block-Deltas:")

        for (index, delta) in blockDeltas.enumerated() {
            print(
                String(
                    format:
                        "Block %d: %+.4f",
                    index + 1,
                    delta
                )
            )
        }

        print("")
        print("Interpretation:")
        print("- Recency 50 und Top 2 waren vorher festgelegt.")
        print("- Kein Fenster wird anhand dieser Bestätigungsdaten ausgewählt.")
        print("- Die drei Blöcke liegen vollständig vor dem bisherigen 290er Holdout.")
        print("- Positives Δ in mehreren Blöcken wäre deutlich überzeugender als ein einzelner Peak.")
        print("")
        print(
            String(
                format:
                    "⏱ Recency-50-Confirmation: %.2f Sekunden",
                Date().timeIntervalSince(start)
            )
        )
        print("===================================")
    }

    private func evaluateModel(
        draws: [EuroJackpotDraw],
        startIndex: Int,
        endIndex: Int
    ) -> Double {

        let hits = evaluateModelHits(
            draws: draws,
            startIndex: startIndex,
            endIndex: endIndex
        )

        let tickets = endIndex - startIndex

        guard tickets > 0 else {
            return 0
        }

        return Double(hits) / Double(tickets)
    }

    private func evaluateModelHits(
        draws: [EuroJackpotDraw],
        startIndex: Int,
        endIndex: Int
    ) -> Int {

        var hits = 0

        for index in startIndex..<endIndex {

            let trainingDraws =
                Array(draws.prefix(index))

            let targetDraw = draws[index]

            let maximumEuro =
                targetDraw.date < euroFormatCutoverDate()
                ? 10
                : 12

            let recentDraws =
                Array(
                    trainingDraws.suffix(
                        min(window, trainingDraws.count)
                    )
                )

            var frequencies: [Int: Int] = [:]

            for number in 1...maximumEuro {
                frequencies[number] = 0
            }

            for draw in recentDraws {
                for euroNumber in draw.euroNumbers
                where euroNumber <= maximumEuro {

                    frequencies[euroNumber, default: 0] += 1
                }
            }

            let selected =
                (1...maximumEuro)
                    .sorted {
                        let lhs = frequencies[$0] ?? 0
                        let rhs = frequencies[$1] ?? 0

                        if lhs == rhs {
                            return $0 < $1
                        }

                        return lhs > rhs
                    }
                    .prefix(selectionCount)

            hits += commonHitCount(
                Array(selected),
                targetDraw.euroNumbers
            )
        }

        return hits
    }

    private func evaluateRandom(
        draws: [EuroJackpotDraw],
        startIndex: Int,
        endIndex: Int
    ) -> [Double] {

        var results: [Double] = []
        results.reserveCapacity(monteCarloRuns)

        for run in 0..<monteCarloRuns {

            let rng = SeededEuroRandomGenerator(
                seed:
                    0xEF_CA_5000
                    &+ UInt64(run)
            )

            var hits = 0
            var tickets = 0

            for index in startIndex..<endIndex {

                let targetDraw = draws[index]

                let maximumEuro =
                    targetDraw.date < euroFormatCutoverDate()
                    ? 10
                    : 12

                var selected: [Int] = []

                while selected.count < selectionCount {

                    let value =
                        rng.nextInt(
                            upperBound: maximumEuro
                        ) + 1

                    if !selected.contains(value) {
                        selected.append(value)
                    }
                }

                hits += commonHitCount(
                    selected,
                    targetDraw.euroNumbers
                )

                tickets += 1
            }

            if tickets > 0 {
                results.append(
                    Double(hits) /
                    Double(tickets)
                )
            }
        }

        return results
    }

    @inline(__always)
    private func commonHitCount(
        _ lhs: [Int],
        _ rhs: [Int]
    ) -> Int {

        var count = 0

        for value in lhs where rhs.contains(value) {
            count += 1
        }

        return count
    }

    private func mean(
        _ values: [Double]
    ) -> Double {

        guard !values.isEmpty else {
            return 0
        }

        return values.reduce(0, +) /
            Double(values.count)
    }

    private func pairedConfidenceInterval(
        _ values: [Double]
    ) -> Double {

        guard values.count > 1 else {
            return 0
        }

        let average = mean(values)

        let variance =
            values.reduce(0.0) {
                partial,
                value in
                partial +
                pow(value - average, 2)
            }
            / Double(values.count - 1)

        return 1.96 *
            sqrt(variance) /
            sqrt(Double(values.count))
    }

    private func euroFormatCutoverDate() -> Date {

        var components = DateComponents()
        components.year = 2022
        components.month = 3
        components.day = 25

        return Calendar.current.date(
            from: components
        ) ?? Date.distantFuture
    }
}

private final class SeededEuroRandomGenerator {

    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    @inline(__always)
    func nextUInt64() -> UInt64 {
        state =
            state &* 6364136223846793005
            &+ 1442695040888963407

        return state
    }

    @inline(__always)
    func nextInt(
        upperBound: Int
    ) -> Int {

        guard upperBound > 0 else {
            return 0
        }

        return Int(
            nextUInt64() %
            UInt64(upperBound)
        )
    }
}
