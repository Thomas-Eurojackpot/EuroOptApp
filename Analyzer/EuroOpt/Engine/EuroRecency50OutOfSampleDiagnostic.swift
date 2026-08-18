//
//  EuroRecency50OutOfSampleDiagnostic.swift
//  EuroOpt
//

import Foundation

final class EuroRecency50OutOfSampleDiagnostic {

    private let window = 50
    private let selectionCount = 2
    private let testCount = 100
    private let monteCarloRuns = 500

    func run(draws: [EuroJackpotDraw]) {

        guard draws.count > testCount + window else {
            print("❌ Recency-50-OOS: zu wenige Ziehungen")
            return
        }

        let start = Date()

        let testStart = draws.count - testCount
        let testEnd = draws.count

        var modelHits = 0
        var randomResults: [Double] = []

        randomResults.reserveCapacity(monteCarloRuns)

        print("")
        print("===================================")
        print("🎯 EURO-RECENCY 50 – OUT-OF-SAMPLE")
        print("===================================")
        print("Signal            : Recency 50 / Top 2")
        print("Testziehungen     : \(testCount)")
        print("Monte-Carlo       : \(monteCarloRuns)")
        print("Training          : ausschließlich vor jeweiliger Ziehung")
        print("")
        print(
            "Testbereich       : \(dateString(draws[testStart].date)) – \(dateString(draws[testEnd - 1].date))"
        )
        print("")

        for index in testStart..<testEnd {

            let frequencies =
                frequenciesBefore(
                    draws: draws,
                    endIndex: index
                )

            let ranked =
                frequencies.keys.sorted {
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

            let selected =
                Array(
                    ranked.prefix(selectionCount)
                )

            modelHits += commonHitCount(
                selected,
                draws[index].euroNumbers
            )
        }

        let modelAverage =
            Double(modelHits) /
            Double(testCount)

        for run in 0..<monteCarloRuns {

            let rng =
                SeededEuroRandomGenerator(
                    seed:
                        0xEF_50_00_00
                        &+ UInt64(run)
                )

            var hits = 0

            for index in testStart..<testEnd {

                let maximum =
                    draws[index].date <
                    euroFormatCutoverDate()
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

            randomResults.append(
                Double(hits) /
                Double(testCount)
            )
        }

        let randomAverage =
            mean(randomResults)

        let deltas =
            randomResults.map {
                modelAverage - $0
            }

        let delta =
            mean(deltas)

        let confidenceInterval =
            pairedConfidenceInterval(deltas)

        print("-----------------------------------")
        print("ERGEBNIS")
        print("-----------------------------------")

        print(
            String(
                format:
                    "Modell Recency 50 : %.4f",
                modelAverage
            )
        )

        print(
            String(
                format:
                    "Zufall            : %.4f",
                randomAverage
            )
        )

        print(
            String(
                format:
                    "Δ Modell - Zufall : %+.4f",
                delta
            )
        )

        print(
            String(
                format:
                    "95%% CI Δ          : ±%.4f",
                confidenceInterval
            )
        )

        print("")
        print("Interpretation:")
        print("- Der Testbereich wird nicht zur Auswahl von Recency 50 verwendet.")
        print("- Die Top-2 werden für jede Testziehung ausschließlich aus vorherigen Ziehungen bestimmt.")
        print("- Kein Fenster und kein Filter wird anhand des Testbereichs optimiert.")
        print("")
        print(
            String(
                format:
                    "⏱ Recency-50-OOS: %.2f Sekunden",
                Date().timeIntervalSince(start)
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
            max(0, endIndex - window)

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
