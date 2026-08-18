//
//  EuroRecency50FullWalkForwardDiagnostic.swift
//  EuroOpt
//

import Foundation

final class EuroRecency50FullWalkForwardDiagnostic {

    private let window = 50
    private let selectionCount = 2
    private let blockCount = 10
    private let monteCarloRuns = 500

    func run(draws: [EuroJackpotDraw]) {

        guard draws.count > window + blockCount else {
            print("❌ Recency-50-Full-WalkForward: zu wenige Ziehungen")
            return
        }

        let startTime = Date()

        let firstTestIndex = window
        let eligibleCount = draws.count - firstTestIndex

        let blockSize =
            Int(
                ceil(
                    Double(eligibleCount) /
                    Double(blockCount)
                )
            )

        print("")
        print("===================================")
        print("🎯 EURO-RECENCY 50 – FULL WALK-FORWARD")
        print("===================================")
        print("Signal            : Recency 50 / Top 2")
        print("Training          : immer letzte 50 Ziehungen")
        print("Test              : jeweils nächste Ziehung")
        print("Historischer Bereich: gesamte verfügbare Historie")
        print("Chronologische Blöcke: \(blockCount)")
        print("Monte-Carlo       : \(monteCarloRuns)")
        print("")

        var totalModelHits = 0
        var totalRandomExpectedHits = 0.0

        var positiveBlocks = 0
        var negativeBlocks = 0

        var blockDeltas: [Double] = []

        for block in 0..<blockCount {

            let blockStart =
                firstTestIndex +
                block * blockSize

            guard blockStart < draws.count else {
                break
            }

            let blockEnd =
                min(
                    blockStart + blockSize,
                    draws.count
                )

            let blockCountActual =
                blockEnd - blockStart

            guard blockCountActual > 0 else {
                continue
            }

            var modelHits = 0
            var randomResults: [Double] = []

            randomResults.reserveCapacity(
                monteCarloRuns
            )

            for index in blockStart..<blockEnd {

                let frequencies =
                    frequenciesBefore(
                        draws: draws,
                        endIndex: index
                    )

                let ranked =
                    frequencies.keys.sorted {
                        let lhs =
                            frequencies[$0] ?? 0

                        let rhs =
                            frequencies[$1] ?? 0

                        if lhs == rhs {
                            return $0 < $1
                        }

                        return lhs > rhs
                    }

                guard ranked.count >= selectionCount else {
                    continue
                }

                let selected =
                    Array(
                        ranked.prefix(
                            selectionCount
                        )
                    )

                modelHits +=
                    commonHitCount(
                        selected,
                        draws[index].euroNumbers
                    )
            }

            let modelAverage =
                Double(modelHits) /
                Double(blockCountActual)

            for run in 0..<monteCarloRuns {

                let rng =
                    SeededEuroRandomGenerator(
                        seed:
                            0xEF_50_FF_00
                            &+
                            UInt64(block * 1000)
                            &+
                            UInt64(run)
                    )

                var hits = 0

                for index in blockStart..<blockEnd {

                    let maximum =
                        draws[index].date <
                        euroFormatCutoverDate()
                        ? 10
                        : 12

                    var selected: [Int] = []

                    while selected.count <
                            selectionCount {

                        let value =
                            rng.nextInt(
                                upperBound: maximum
                            ) + 1

                        if !selected.contains(value) {
                            selected.append(value)
                        }
                    }

                    hits +=
                        commonHitCount(
                            selected,
                            draws[index].euroNumbers
                        )
                }

                randomResults.append(
                    Double(hits) /
                    Double(blockCountActual)
                )
            }

            let randomAverage =
                mean(randomResults)

            let delta =
                modelAverage -
                randomAverage

            totalModelHits += modelHits
            totalRandomExpectedHits +=
                randomAverage *
                Double(blockCountActual)

            blockDeltas.append(delta)

            if delta >= 0 {
                positiveBlocks += 1
            } else {
                negativeBlocks += 1
            }

            print(
                String(
                    format:
                        "Block %02d | %@ – %@ | Modell %.4f | Zufall %.4f | Δ %+.4f",
                    block + 1,
                    dateString(
                        draws[blockStart].date
                    ),
                    dateString(
                        draws[blockEnd - 1].date
                    ),
                    modelAverage,
                    randomAverage,
                    delta
                )
            )
        }

        let actualBlockCount =
            blockDeltas.count

        let totalTestCount =
            eligibleCount

        let totalModelAverage =
            Double(totalModelHits) /
            Double(totalTestCount)

        let totalRandomAverage =
            totalRandomExpectedHits /
            Double(totalTestCount)

        let totalDelta =
            totalModelAverage -
            totalRandomAverage

        let averageBlockDelta =
            mean(blockDeltas)

        print("")
        print("-----------------------------------")
        print("FULL WALK-FORWARD ZUSAMMENFASSUNG")
        print("-----------------------------------")

        print(
            String(
                format:
                    "Testziehungen      : %d",
                totalTestCount
            )
        )

        print(
            String(
                format:
                    "Modell             : %.4f",
                totalModelAverage
            )
        )

        print(
            String(
                format:
                    "Zufall             : %.4f",
                totalRandomAverage
            )
        )

        print(
            String(
                format:
                    "Gesamt Δ           : %+.4f",
                totalDelta
            )
        )

        print(
            String(
                format:
                    "Ø Block-Δ          : %+.4f",
                averageBlockDelta
            )
        )

        print(
            "Positive Blöcke    : \(positiveBlocks) / \(actualBlockCount)"
        )

        print(
            "Negative Blöcke    : \(negativeBlocks) / \(actualBlockCount)"
        )

        print("")
        print("Interpretation:")
        print("- Jede Ziehung wird einzeln out-of-sample bewertet.")
        print("- Für jede Ziehung werden ausschließlich die vorherigen 50 Ziehungen verwendet.")
        print("- Recency 50 / Top 2 bleibt über die gesamte Untersuchung unverändert.")
        print("- Die historischen Blöcke werden erst nach der Berechnung betrachtet.")
        print("- Kein Block wird anhand seines Ergebnisses ausgewählt.")
        print("- Entscheidend sind Gesamt-Δ und die Stabilität über die 10 Blöcke.")

        print("")
        print(
            String(
                format:
                    "⏱ Full Walk-Forward: %.2f Sekunden",
                Date().timeIntervalSince(startTime)
            )
        )

        print("===================================")
    }

    private func frequenciesBefore(
        draws: [EuroJackpotDraw],
        endIndex: Int
    ) -> [Int: Int] {

        var frequencies: [Int: Int] = [:]

        let start =
            max(
                0,
                endIndex - window
            )

        for index in start..<endIndex {

            for number in draws[index].euroNumbers {
                frequencies[number, default: 0] += 1
            }
        }

        return frequencies
    }

    private func commonHitCount(
        _ lhs: [Int],
        _ rhs: [Int]
    ) -> Int {

        var count = 0

        for value in lhs {

            if rhs.contains(value) {
                count += 1
            }
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

        let formatter =
            DateFormatter()

        formatter.dateFormat =
            "yyyy-MM-dd"

        return formatter.string(
            from: date
        )
    }

    private func euroFormatCutoverDate() -> Date {

        var components =
            DateComponents()

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
            state &*
            6364136223846793005
            &+
            1442695040888963407

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
