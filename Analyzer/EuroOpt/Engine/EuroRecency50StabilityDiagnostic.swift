//
//  EuroRecency50StabilityDiagnostic.swift
//  EuroOpt
//

import Foundation

final class EuroRecency50StabilityDiagnostic {

    private let blockSize = 40
    private let monteCarloRuns = 200

    func run(draws: [EuroJackpotDraw]) {

        guard draws.count > 200 else {
            print("❌ Recency-50-Stabilität: zu wenige Ziehungen")
            return
        }

        let start = Date()

        let endIndex = min(389, draws.count)
        let firstEvaluationIndex = 100

        print("")
        print("===================================")
        print("🎯 EURO-RECENCY 50 – STABILITÄT")
        print("===================================")
        print("Signal            : Recency 50 / Top 2")
        print("Vergleich         : Fenster 30 / 40 / 50")
        print("Blockgröße        : \(blockSize)")
        print("Monte-Carlo       : \(monteCarloRuns)")
        print("Bereich           : vor bisherigem Holdout")
        print("")

        var currentStart = firstEvaluationIndex
        var blockNumber = 1

        var highStabilityDeltas: [Double] = []
        var lowStabilityDeltas: [Double] = []

        while currentStart + blockSize <= endIndex {

            let currentEnd = currentStart + blockSize

            let top30 = topTwo(
                draws: draws,
                endIndex: currentStart,
                window: 30
            )

            let top40 = topTwo(
                draws: draws,
                endIndex: currentStart,
                window: 40
            )

            let top50 = topTwo(
                draws: draws,
                endIndex: currentStart,
                window: 50
            )

            let overlap30_50 =
                commonCount(top30, top50)

            let overlap40_50 =
                commonCount(top40, top50)

            let stability =
                overlap30_50 + overlap40_50

            let modelAverage =
                evaluateRecency50(
                    draws: draws,
                    startIndex: currentStart,
                    endIndex: currentEnd
                )

            let randomValues =
                evaluateRandom(
                    draws: draws,
                    startIndex: currentStart,
                    endIndex: currentEnd,
                    seedOffset: blockNumber
                )

            let randomAverage =
                mean(randomValues)

            let delta =
                modelAverage - randomAverage

            let highStability =
                stability >= 3

            if highStability {
                highStabilityDeltas.append(delta)
            } else {
                lowStabilityDeltas.append(delta)
            }

            let firstDate =
                dateString(draws[currentStart].date)

            let lastDate =
                dateString(draws[currentEnd - 1].date)

            print(
                String(
                    format:
                        "Block %02d | %@ – %@ | 30/50 %d | 40/50 %d | Stabilität %d | Δ %+.4f | %@",
                    blockNumber,
                    firstDate,
                    lastDate,
                    overlap30_50,
                    overlap40_50,
                    stability,
                    delta,
                    highStability ? "HOCH" : "NIEDRIG"
                )
            )

            currentStart += blockSize
            blockNumber += 1
        }

        print("")
        print("-----------------------------------")
        print("STABILITÄTS-VERGLEICH")
        print("-----------------------------------")

        print(
            String(
                format:
                    "HOHE Stabilität   : %d Blöcke | Ø Δ %+.4f",
                highStabilityDeltas.count,
                mean(highStabilityDeltas)
            )
        )

        print(
            String(
                format:
                    "NIEDRIGE Stabilität: %d Blöcke | Ø Δ %+.4f",
                lowStabilityDeltas.count,
                mean(lowStabilityDeltas)
            )
        )

        print("")
        print("Definition HOCH:")
        print("Top-2-Überschneidung 30/50 + 40/50 >= 3")

        print("")
        print("Interpretation:")
        print("- Die Stabilität wird ausschließlich vor dem jeweiligen Block berechnet.")
        print("- Recency 50 / Top 2 bleibt unverändert.")
        print("- Kein Schwellenwert wird anhand des Blockergebnisses gewählt.")
        print("- Entscheidend ist, ob hohe Stabilität mit höherem Δ verbunden ist.")
        print("")
        print(
            String(
                format:
                    "⏱ Recency-50-Stabilität: %.2f Sekunden",
                Date().timeIntervalSince(start)
            )
        )
        print("===================================")
    }

    private func topTwo(
        draws: [EuroJackpotDraw],
        endIndex: Int,
        window: Int
    ) -> [Int] {

        var frequencies: [Int: Int] = [:]

        let start =
            max(0, endIndex - window)

        for index in start..<endIndex {

            for number in draws[index].euroNumbers {
                frequencies[number, default: 0] += 1
            }
        }

        return Array(
            frequencies.keys.sorted {
                let lhs = frequencies[$0] ?? 0
                let rhs = frequencies[$1] ?? 0

                if lhs == rhs {
                    return $0 < $1
                }

                return lhs > rhs
            }
            .prefix(2)
        )
    }

    private func evaluateRecency50(
        draws: [EuroJackpotDraw],
        startIndex: Int,
        endIndex: Int
    ) -> Double {

        var hits = 0

        for index in startIndex..<endIndex {

            let selected =
                topTwo(
                    draws: draws,
                    endIndex: index,
                    window: 50
                )

            hits += commonHitCount(
                selected,
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
                        0xEF_50_57_00
                        &+ UInt64(seedOffset * 1000)
                        &+ UInt64(run)
                )

            var hits = 0

            for index in startIndex..<endIndex {

                let maximum =
                    draws[index].date <
                    euroFormatCutoverDate()
                    ? 10
                    : 12

                var selected: [Int] = []

                while selected.count < 2 {

                    let value =
                        rng.nextInt(
                            upperBound: maximum
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

    private func commonCount(
        _ lhs: [Int],
        _ rhs: [Int]
    ) -> Int {

        lhs.filter {
            rhs.contains($0)
        }.count
    }

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
