//
//  EuroRecency50DepthDiagnostic.swift
//  EuroOpt
//
//  Recency-50-Tiefentest: Top 1 bis Top 4
//

import Foundation

final class EuroRecency50DepthDiagnostic {

    private let monteCarloRuns = 200
    private let window = 50

    func run(draws: [EuroJackpotDraw]) {

        guard draws.count > 150 else {
            print("❌ Euro-Recency-50-Depth: zu wenige Ziehungen")
            return
        }

        let start = Date()

        let totalTests = draws.count - 100
        let validationTests = totalTests / 2
        let holdoutStart = 100 + validationTests
        let holdoutCount = draws.count - holdoutStart

        print("")
        print("===================================")
        print("🎯 EURO-RECENCY 50 – DEPTH-TEST")
        print("===================================")
        print("Holdout-Ziehungen : \(holdoutCount)")
        print("Signal            : Häufigkeit letzte 50 Ziehungen")
        print("Auswahlgrößen     : Top 1 / 2 / 3 / 4")
        print("Monte-Carlo       : \(monteCarloRuns)")
        print("")

        for selectionCount in 1...4 {

            let modelAverage = evaluateModel(
                draws: draws,
                holdoutStart: holdoutStart,
                selectionCount: selectionCount
            )

            let randomAverages = evaluateRandom(
                draws: draws,
                holdoutStart: holdoutStart,
                selectionCount: selectionCount
            )

            let randomAverage = mean(randomAverages)

            let deltas = randomAverages.map {
                modelAverage - $0
            }

            let delta = mean(deltas)
            let confidenceInterval =
                pairedConfidenceInterval(deltas)

            print(
                String(
                    format:
                        "Top %d | Modell %.4f | Zufall %.4f | Δ %+.4f | 95%% CI ±%.4f",
                    selectionCount,
                    modelAverage,
                    randomAverage,
                    delta,
                    confidenceInterval
                )
            )
        }

        print("")
        print("Theorie:")
        print("- 10 Eurozahlen: \(String(format: "%.4f", 1.0 / 5.0)) pro ausgewählter Zahl")
        print("- 12 Eurozahlen: \(String(format: "%.4f", 1.0 / 6.0)) pro ausgewählter Zahl")
        print("")
        print("Interpretation:")
        print("- Zufall verwendet exakt dieselbe Anzahl Eurozahlen wie das Modell.")
        print("- Alle Entscheidungen basieren ausschließlich auf den Trainingsziehungen.")
        print("- Recency-50 wird nicht neu optimiert.")
        print("")
        print(
            String(
                format:
                    "⏱ Euro-Recency-50-Depth: %.2f Sekunden",
                Date().timeIntervalSince(start)
            )
        )
        print("===================================")
    }

    private func evaluateModel(
        draws: [EuroJackpotDraw],
        holdoutStart: Int,
        selectionCount: Int
    ) -> Double {

        var hits = 0
        var tickets = 0

        for index in holdoutStart..<draws.count {

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

            tickets += 1
        }

        guard tickets > 0 else {
            return 0
        }

        return Double(hits) / Double(tickets)
    }

    private func evaluateRandom(
        draws: [EuroJackpotDraw],
        holdoutStart: Int,
        selectionCount: Int
    ) -> [Double] {

        var results: [Double] = []
        results.reserveCapacity(monteCarloRuns)

        for run in 0..<monteCarloRuns {

            let rng = SeededEuroRandomGenerator(
                seed:
                    0xEF_5000_0000
                    &+ UInt64(selectionCount * 1000)
                    &+ UInt64(run)
            )

            var hits = 0
            var tickets = 0

            for index in holdoutStart..<draws.count {

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
                    Double(hits) / Double(tickets)
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

        return values.reduce(0, +)
            / Double(values.count)
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
            nextUInt64()
            % UInt64(upperBound)
        )
    }
}
