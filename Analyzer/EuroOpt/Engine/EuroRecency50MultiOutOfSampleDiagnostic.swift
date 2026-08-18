//
//  EuroRecency50MultiOutOfSampleDiagnostic.swift
//  EuroOpt
//

import Foundation

final class EuroRecency50MultiOutOfSampleDiagnostic {

    private let window = 50
    private let selectionCount = 2
    private let testWindow = 100
    private let windowCount = 4
    private let monteCarloRuns = 500

    func run(draws: [EuroJackpotDraw]) {

        guard draws.count >= window + testWindow * windowCount else {
            print("❌ Multi-OOS: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let testStart = draws.count - testWindow * windowCount

        print("")
        print("===================================")
        print("🎯 EURO-RECENCY 50 – MULTI OOS")
        print("===================================")
        print("Signal            : Recency 50 / Top 2")
        print("OOS-Fenster       : \(windowCount) × \(testWindow)")
        print("Monte-Carlo       : \(monteCarloRuns)")
        print("Training          : ausschließlich vor jeweiliger Ziehung")
        print("")

        var totalModelHits = 0
        var totalRandomAverage = 0.0
        var positiveWindows = 0
        var negativeWindows = 0

        for windowIndex in 0..<windowCount {

            let startIndex =
                testStart + windowIndex * testWindow

            let endIndex =
                startIndex + testWindow

            var modelHits = 0
            var randomResults: [Double] = []

            for index in startIndex..<endIndex {

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

                modelHits += commonHitCount(
                    Array(ranked.prefix(selectionCount)),
                    draws[index].euroNumbers
                )
            }

            let modelAverage =
                Double(modelHits) / Double(testWindow)

            for run in 0..<monteCarloRuns {

                let rng =
                    SeededEuroRandomGenerator(
                        seed:
                            0xEF_50_A0_00
                            &+ UInt64(windowIndex * 1000)
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

                randomResults.append(
                    Double(hits) / Double(testWindow)
                )
            }

            let randomAverage = mean(randomResults)
            let delta = modelAverage - randomAverage

            totalModelHits += modelHits
            totalRandomAverage += randomAverage

            if delta >= 0 {
                positiveWindows += 1
            } else {
                negativeWindows += 1
            }

            print(
                String(
                    format:
                        "OOS %d | %@ – %@ | Modell %.4f | Zufall %.4f | Δ %+.4f",
                    windowIndex + 1,
                    dateString(draws[startIndex].date),
                    dateString(draws[endIndex - 1].date),
                    modelAverage,
                    randomAverage,
                    delta
                )
            )
        }

        let totalTickets =
            testWindow * windowCount

        let totalModelAverage =
            Double(totalModelHits) /
            Double(totalTickets)

        let totalRandomAverageValue =
            totalRandomAverage /
            Double(windowCount)

        let totalDelta =
            totalModelAverage -
            totalRandomAverageValue

        print("")
        print("-----------------------------------")
        print("MULTI-OOS-ZUSAMMENFASSUNG")
        print("-----------------------------------")

        print(
            String(
                format:
                    "Gesamt Modell      : %.4f",
                totalModelAverage
            )
        )

        print(
            String(
                format:
                    "Gesamt Zufall      : %.4f",
                totalRandomAverageValue
            )
        )

        print(
            String(
                format:
                    "Gesamt Δ           : %+.4f",
                totalDelta
            )
        )

        print("")
        print("Positive Fenster   : \(positiveWindows) / \(windowCount)")
        print("Negative Fenster   : \(negativeWindows) / \(windowCount)")

        print("")
        print("Interpretation:")
        print("- Alle vier OOS-Fenster sind vorher festgelegt.")
        print("- Recency 50 / Top 2 bleibt unverändert.")
        print("- Jede Testziehung verwendet ausschließlich vorherige Ziehungen.")
        print("- Kein Fenster wird anhand seines Ergebnisses optimiert.")
        print("- Entscheidend ist die Wiederholbarkeit des Signals.")
        print("")
        print(
            String(
                format:
                    "⏱ Multi-OOS: %.2f Sekunden",
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
