//
//  EuroRecency50RollingDiagnostic.swift
//  EuroOpt
//
//  Rollierender Stabilitätstest für festgelegtes Recency-50 / Top-2-Signal
//

import Foundation

final class EuroRecency50RollingDiagnostic {

    private let window = 50
    private let selectionCount = 2
    private let blockSize = 40
    private let monteCarloRuns = 200

    func run(draws: [EuroJackpotDraw]) {

        guard draws.count > 200 else {
            print("❌ Recency-50-Rolling: zu wenige Ziehungen")
            return
        }

        let start = Date()

        // Der bisher verwendete Holdout beginnt bei Index 389.
        // Wir untersuchen ausschließlich die davor liegende Historie.
        let endIndex = min(389, draws.count)
        let firstEvaluationIndex = 100

        guard endIndex - firstEvaluationIndex >= blockSize else {
            print("❌ Recency-50-Rolling: zu wenig Auswertungsdaten")
            return
        }

        print("")
        print("===================================")
        print("🎯 EURO-RECENCY 50 – ROLLING-TEST")
        print("===================================")
        print("Signal            : Recency 50")
        print("Auswahl           : Top 2")
        print("Blockgröße        : \(blockSize) Ziehungen")
        print("Bereich           : vor bisherigem Holdout")
        print("Monte-Carlo       : \(monteCarloRuns)")
        print("")

        var blockNumber = 1
        var currentStart = firstEvaluationIndex

        var positiveBlocks = 0
        var negativeBlocks = 0

        var allModelHits = 0
        var allRandomHits = 0
        var allTickets = 0

        while currentStart + blockSize <= endIndex {

            let currentEnd = currentStart + blockSize

            let modelHits = evaluateModelHits(
                draws: draws,
                startIndex: currentStart,
                endIndex: currentEnd
            )

            let modelAverage =
                Double(modelHits) /
                Double(blockSize)

            let randomAverages = evaluateRandom(
                draws: draws,
                startIndex: currentStart,
                endIndex: currentEnd,
                seedOffset: blockNumber
            )

            let randomAverage = mean(randomAverages)

            let deltas = randomAverages.map {
                modelAverage - $0
            }

            let delta = mean(deltas)

            let confidenceInterval =
                pairedConfidenceInterval(deltas)

            if delta > 0 {
                positiveBlocks += 1
            } else {
                negativeBlocks += 1
            }

            allModelHits += modelHits

            allRandomHits += Int(
                round(
                    randomAverage *
                    Double(blockSize)
                )
            )

            allTickets += blockSize

            let firstDate = draws[currentStart].date
            let lastDate = draws[currentEnd - 1].date

            print(
                String(
                    format:
                        "Block %02d | %@ – %@ | Modell %.4f | Zufall %.4f | Δ %+.4f | 95%% CI ±%.4f",
                    blockNumber,
                    dateString(firstDate),
                    dateString(lastDate),
                    modelAverage,
                    randomAverage,
                    delta,
                    confidenceInterval
                )
            )

            blockNumber += 1
            currentStart += blockSize
        }

        let combinedModel =
            Double(allModelHits) /
            Double(allTickets)

        let combinedRandom =
            Double(allRandomHits) /
            Double(allTickets)

        let combinedDelta =
            combinedModel - combinedRandom

        let totalBlocks = positiveBlocks + negativeBlocks

        print("")
        print("-----------------------------------")
        print("ROLLING-ZUSAMMENFASSUNG")
        print("-----------------------------------")
        print("Positive Blöcke : \(positiveBlocks) / \(totalBlocks)")
        print("Negative Blöcke : \(negativeBlocks) / \(totalBlocks)")

        print(
            String(
                format:
                    "Gesamt Modell   : %.4f",
                combinedModel
            )
        )

        print(
            String(
                format:
                    "Gesamt Zufall   : %.4f",
                combinedRandom
            )
        )

        print(
            String(
                format:
                    "Gesamt Δ        : %+.4f",
                combinedDelta
            )
        )

        print("")
        print("Interpretation:")
        print("- Recency 50 und Top 2 waren vorher festgelegt.")
        print("- Kein Fenster wird anhand eines Rolling-Blocks gewählt.")
        print("- Jeder Block verwendet nur Informationen vor der jeweiligen Ziehung.")
        print("- Entscheidend ist die Stabilität über viele Blöcke.")
        print("")
        print(
            String(
                format:
                    "⏱ Recency-50-Rolling: %.2f Sekunden",
                Date().timeIntervalSince(start)
            )
        )
        print("===================================")
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
        endIndex: Int,
        seedOffset: Int
    ) -> [Double] {

        var results: [Double] = []
        results.reserveCapacity(monteCarloRuns)

        for run in 0..<monteCarloRuns {

            let rng = SeededEuroRandomGenerator(
                seed:
                    0xEF_50_77_00
                    &+ UInt64(seedOffset * 1000)
                    &+ UInt64(run)
            )

            var hits = 0

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
            }

            results.append(
                Double(hits) /
                Double(endIndex - startIndex)
            )
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

    private func dateString(
        _ date: Date
    ) -> String {

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter.string(from: date)
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
