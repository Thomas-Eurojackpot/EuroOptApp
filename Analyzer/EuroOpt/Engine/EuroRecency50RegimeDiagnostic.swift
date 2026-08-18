//
//  EuroRecency50RegimeDiagnostic.swift
//  EuroOpt
//

import Foundation

final class EuroRecency50RegimeDiagnostic {

    private let window = 50
    private let selectionCount = 2
    private let blockSize = 40
    private let monteCarloRuns = 200

    func run(draws: [EuroJackpotDraw]) {

        guard draws.count > 200 else {
            print("❌ Recency-50-Regime: zu wenige Ziehungen")
            return
        }

        let start = Date()

        let endIndex = min(389, draws.count)
        let firstEvaluationIndex = 100

        var strongDeltas: [Double] = []
        var weakDeltas: [Double] = []

        var strongBlocks = 0
        var weakBlocks = 0

        var currentStart = firstEvaluationIndex
        var blockNumber = 1

        print("")
        print("===================================")
        print("🎯 EURO-RECENCY 50 – REGIME-TEST")
        print("===================================")
        print("Signal            : Recency 50 / Top 2")
        print("Analyse           : Konzentration")
        print("Blockgröße        : \(blockSize)")
        print("Monte-Carlo       : \(monteCarloRuns)")
        print("Bereich           : vor bisherigem Holdout")
        print("")

        while currentStart + blockSize <= endIndex {

            let currentEnd =
                currentStart + blockSize

            let frequencies =
                frequenciesBefore(
                    draws: draws,
                    endIndex: currentStart
                )

            let ranked =
                rankedNumbers(
                    frequencies: frequencies
                )

            guard ranked.count >= 3 else {
                currentStart += blockSize
                blockNumber += 1
                continue
            }

            let top1 =
                frequencies[ranked[0]] ?? 0

            let top2 =
                frequencies[ranked[1]] ?? 0

            let top3 =
                frequencies[ranked[2]] ?? 0

            let totalFrequency =
                frequencies.values.reduce(0, +)

            let top2Share =
                totalFrequency > 0
                ? Double(top1 + top2) /
                  Double(totalFrequency)
                : 0

            let gap23 =
                top2 - top3

            let modelAverage =
                evaluateModel(
                    draws: draws,
                    startIndex: currentStart,
                    endIndex: currentEnd
                )

            let randomAverages =
                evaluateRandom(
                    draws: draws,
                    startIndex: currentStart,
                    endIndex: currentEnd,
                    seedOffset: blockNumber
                )

            let randomAverage =
                mean(randomAverages)

            let deltas =
                randomAverages.map {
                    modelAverage - $0
                }

            let delta =
                mean(deltas)

            let confidenceInterval =
                pairedConfidenceInterval(deltas)

            let strong =
                top2Share >= 0.19 &&
                gap23 >= 2

            if strong {
                strongBlocks += 1
                strongDeltas.append(delta)
            } else {
                weakBlocks += 1
                weakDeltas.append(delta)
            }

            let firstDate =
                draws[currentStart].date

            let lastDate =
                draws[currentEnd - 1].date

            print(
                String(
                    format:
                        "Block %02d | %@ – %@ | Top2 %.3f | Gap23 %d | Modell %.4f | Zufall %.4f | Δ %+.4f | 95%% CI ±%.4f | %@",
                    blockNumber,
                    dateString(firstDate),
                    dateString(lastDate),
                    top2Share,
                    gap23,
                    modelAverage,
                    randomAverage,
                    delta,
                    confidenceInterval,
                    strong ? "STARK" : "SCHWACH"
                )
            )

            currentStart += blockSize
            blockNumber += 1
        }

        print("")
        print("-----------------------------------")
        print("REGIME-VERGLEICH")
        print("-----------------------------------")

        print(
            String(
                format:
                    "STARK   : %d Blöcke | Ø Δ %+.4f",
                strongBlocks,
                mean(strongDeltas)
            )
        )

        print(
            String(
                format:
                    "SCHWACH : %d Blöcke | Ø Δ %+.4f",
                weakBlocks,
                mean(weakDeltas)
            )
        )

        print("")
        print("Definition STARK:")
        print("Top-2-Anteil >= 19 % UND Abstand Top2/Top3 >= 2")

        print("")
        print("Interpretation:")
        print("- Zufall wird per Monte-Carlo gegen das Modell verglichen.")
        print("- Der Regime-Faktor wird ausschließlich aus den Trainingsdaten bestimmt.")
        print("- Kein Block wird anhand seines Ergebnisses als stark oder schwach eingestuft.")
        print("- Entscheidend ist, ob STARK einen deutlich höheren Ø Δ als SCHWACH besitzt.")
        print("")
        print(
            String(
                format:
                    "⏱ Recency-50-Regime: %.2f Sekunden",
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

        var hits = 0

        for index in startIndex..<endIndex {

            let frequencies =
                frequenciesBefore(
                    draws: draws,
                    endIndex: index
                )

            let ranked =
                rankedNumbers(
                    frequencies: frequencies
                )

            guard ranked.count >= selectionCount else {
                continue
            }

            hits += commonHitCount(
                Array(ranked.prefix(selectionCount)),
                draws[index].euroNumbers
            )
        }

        return Double(hits) /
            Double(endIndex - startIndex)
    }

    private func evaluateRandom(
        draws: [EuroJackpotDraw],
        startIndex: Int,
        endIndex: Int,
        seedOffset: Int
    ) -> [Double] {

        var results: [Double] = []

        for run in 0..<monteCarloRuns {

            let rng =
                SeededEuroRandomGenerator(
                    seed:
                        0xEF_50_AA_00
                        &+ UInt64(seedOffset * 1000)
                        &+ UInt64(run)
                )

            var hits = 0

            for index in startIndex..<endIndex {

                let maximumEuro =
                    draws[index].date < euroFormatCutoverDate()
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
                    draws[index].euroNumbers
                )
            }

            results.append(
                Double(hits) /
                Double(endIndex - startIndex)
            )
        }

        return results
    }

    private func frequenciesBefore(
        draws: [EuroJackpotDraw],
        endIndex: Int
    ) -> [Int: Int] {

        var frequencies: [Int: Int] = [:]

        let start =
            max(0, endIndex - window)

        for index in start..<endIndex {

            for number in draws[index].euroNumbers {
                frequencies[number, default: 0] += 1
            }
        }

        return frequencies
    }

    private func rankedNumbers(
        frequencies: [Int: Int]
    ) -> [Int] {

        frequencies.keys.sorted {
            let lhs = frequencies[$0] ?? 0
            let rhs = frequencies[$1] ?? 0

            if lhs == rhs {
                return $0 < $1
            }

            return lhs > rhs
        }
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
