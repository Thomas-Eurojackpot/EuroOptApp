//
//  EuroRecency50WalkForwardDiagnostic.swift
//  EuroOpt
//

import Foundation

final class EuroRecency50WalkForwardDiagnostic {

    private let window = 50
    private let selectionCount = 2
    private let blockSize = 40
    private let monteCarloRuns = 200

    func run(draws: [EuroJackpotDraw]) {

        guard draws.count > 200 else {
            print("❌ Recency-50-WalkForward: zu wenige Ziehungen")
            return
        }

        let start = Date()

        let endIndex = min(389, draws.count)
        let firstEvaluationIndex = 100

        var strategyHits = 0
        var recencyHits = 0
        var randomHits = 0
        var strategyTickets = 0

        var activeBlocks = 0
        var inactiveBlocks = 0

        print("")
        print("===================================")
        print("🎯 EURO-RECENCY 50 – WALK-FORWARD")
        print("===================================")
        print("Signal            : Recency 50 / Top 2")
        print("Regime-Filter     : Top2 >= 19 % UND Gap >= 2")
        print("Blockgröße        : \(blockSize)")
        print("Monte-Carlo       : \(monteCarloRuns)")
        print("Bereich           : vor bisherigem Holdout")
        print("")

        var currentStart = firstEvaluationIndex
        var blockNumber = 1

        while currentStart + blockSize <= endIndex {

            let currentEnd = currentStart + blockSize

            let regime = regimeBefore(
                draws: draws,
                endIndex: currentStart
            )

            let strategyBlockHits: Int

            if regime {
                strategyBlockHits = evaluateRecencyHits(
                    draws: draws,
                    startIndex: currentStart,
                    endIndex: currentEnd
                )
                activeBlocks += 1
            } else {
                strategyBlockHits = evaluateRandomExpectedHits(
                    draws: draws,
                    startIndex: currentStart,
                    endIndex: currentEnd,
                    seedOffset: blockNumber
                )
                inactiveBlocks += 1
            }

            let recencyBlockHits = evaluateRecencyHits(
                draws: draws,
                startIndex: currentStart,
                endIndex: currentEnd
            )

            let randomAverage = evaluateRandomAverage(
                draws: draws,
                startIndex: currentStart,
                endIndex: currentEnd,
                seedOffset: blockNumber
            )

            let randomBlockHits = Int(
                round(
                    randomAverage * Double(blockSize)
                )
            )

            strategyHits += strategyBlockHits
            recencyHits += recencyBlockHits
            randomHits += randomBlockHits
            strategyTickets += blockSize

            let strategyAverage =
                Double(strategyBlockHits) / Double(blockSize)

            let recencyAverage =
                Double(recencyBlockHits) / Double(blockSize)

            let randomAverageBlock =
                Double(randomBlockHits) / Double(blockSize)

            print(
                String(
                    format:
                        "Block %02d | %@ | Strategie %.4f | Rec50 %.4f | Zufall %.4f | %@",
                    blockNumber,
                    regime ? "AKTIV  " : "INAKTIV",
                    strategyAverage,
                    recencyAverage,
                    randomAverageBlock,
                    regime ? "STARK" : "SCHWACH"
                )
            )

            currentStart += blockSize
            blockNumber += 1
        }

        guard strategyTickets > 0 else {
            print("❌ Recency-50-WalkForward: keine Testblöcke")
            return
        }

        let strategyAverage =
            Double(strategyHits) / Double(strategyTickets)

        let recencyAverage =
            Double(recencyHits) / Double(strategyTickets)

        let randomAverage =
            Double(randomHits) / Double(strategyTickets)

        print("")
        print("-----------------------------------")
        print("WALK-FORWARD-ZUSAMMENFASSUNG")
        print("-----------------------------------")

        print(
            String(
                format:
                    "Strategie          : %.4f",
                strategyAverage
            )
        )

        print(
            String(
                format:
                    "Recency 50         : %.4f",
                recencyAverage
            )
        )

        print(
            String(
                format:
                    "Zufall             : %.4f",
                randomAverage
            )
        )

        print(
            String(
                format:
                    "Strategie - Zufall : %+.4f",
                strategyAverage - randomAverage
            )
        )

        print(
            String(
                format:
                    "Rec50 - Zufall     : %+.4f",
                recencyAverage - randomAverage
            )
        )

        print("")
        print("Aktive Blöcke   : \(activeBlocks)")
        print("Inaktive Blöcke : \(inactiveBlocks)")

        print("")
        print("Interpretation:")
        print("- Die Regime-Entscheidung erfolgt vor jedem Block.")
        print("- Im STARK-Regime wird Recency 50 / Top 2 verwendet.")
        print("- Im SCHWACH-Regime wird Zufall verwendet.")
        print("- Recency 50 wird zusätzlich durchgehend als Vergleich berechnet.")
        print("- Zufall verwendet dieselbe Anzahl Eurozahlen.")
        print("")
        print(
            String(
                format:
                    "⏱ Recency-50-WalkForward: %.2f Sekunden",
                Date().timeIntervalSince(start)
            )
        )
        print("===================================")
    }

    private func regimeBefore(
        draws: [EuroJackpotDraw],
        endIndex: Int
    ) -> Bool {

        var frequencies: [Int: Int] = [:]

        let start = max(0, endIndex - window)

        for index in start..<endIndex {
            for number in draws[index].euroNumbers {
                frequencies[number, default: 0] += 1
            }
        }

        let ranked = frequencies.keys.sorted {
            let lhs = frequencies[$0] ?? 0
            let rhs = frequencies[$1] ?? 0

            if lhs == rhs {
                return $0 < $1
            }

            return lhs > rhs
        }

        guard ranked.count >= 3 else {
            return false
        }

        let top1 = frequencies[ranked[0]] ?? 0
        let top2 = frequencies[ranked[1]] ?? 0
        let top3 = frequencies[ranked[2]] ?? 0

        let total = frequencies.values.reduce(0, +)

        guard total > 0 else {
            return false
        }

        let top2Share =
            Double(top1 + top2) / Double(total)

        let gap = top2 - top3

        return top2Share >= 0.19 && gap >= 2
    }

    private func evaluateRecencyHits(
        draws: [EuroJackpotDraw],
        startIndex: Int,
        endIndex: Int
    ) -> Int {

        var hits = 0

        for index in startIndex..<endIndex {

            let frequencies = frequenciesBefore(
                draws: draws,
                endIndex: index
            )

            let ranked = frequencies.keys.sorted {
                let lhs = frequencies[$0] ?? 0
                let rhs = frequencies[$1] ?? 0

                if lhs == rhs {
                    return $0 < $1
                }

                return lhs > rhs
            }

            guard ranked.count >= selectionCount else {
                continue
            }

            hits += commonHitCount(
                Array(ranked.prefix(selectionCount)),
                draws[index].euroNumbers
            )
        }

        return hits
    }

    private func frequenciesBefore(
        draws: [EuroJackpotDraw],
        endIndex: Int
    ) -> [Int: Int] {

        var frequencies: [Int: Int] = [:]

        let start = max(0, endIndex - window)

        for index in start..<endIndex {
            for number in draws[index].euroNumbers {
                frequencies[number, default: 0] += 1
            }
        }

        return frequencies
    }

    private func evaluateRandomAverage(
        draws: [EuroJackpotDraw],
        startIndex: Int,
        endIndex: Int,
        seedOffset: Int
    ) -> Double {

        var results: [Double] = []
        results.reserveCapacity(monteCarloRuns)

        for run in 0..<monteCarloRuns {

            let rng = SeededEuroRandomGenerator(
                seed:
                    0xEF_50_50_00
                    &+ UInt64(seedOffset * 1000)
                    &+ UInt64(run)
            )

            var hits = 0

            for index in startIndex..<endIndex {

                let maximum =
                    draws[index].date < euroFormatCutoverDate()
                    ? 10
                    : 12

                var selected: [Int] = []

                while selected.count < selectionCount {

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

        return mean(results)
    }

    private func evaluateRandomExpectedHits(
        draws: [EuroJackpotDraw],
        startIndex: Int,
        endIndex: Int,
        seedOffset: Int
    ) -> Int {

        Int(
            round(
                evaluateRandomAverage(
                    draws: draws,
                    startIndex: startIndex,
                    endIndex: endIndex,
                    seedOffset: seedOffset
                ) * Double(endIndex - startIndex)
            )
        )
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
