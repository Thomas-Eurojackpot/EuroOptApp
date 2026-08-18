//
//  EuroRecencyGapHoldoutDiagnostic.swift
//  EuroOpt
//
//  Separater Holdout-Test für Eurozahlen:
//  - Recency 20
//  - Recency 50
//  - Gap
//

import Foundation

final class EuroRecencyGapHoldoutDiagnostic {

    private let monteCarloRuns = 200

    private let recency20Window = 20
    private let recency50Window = 50

    func run(draws: [EuroJackpotDraw]) {

        guard draws.count > 150 else {
            print("❌ Euro-Recency/Gap-Diagnostic: zu wenige Ziehungen")
            return
        }

        let start = Date()

        let totalTests = draws.count - 100
        let validationTests = totalTests / 2
        let holdoutStart = 100 + validationTests
        let holdoutCount = draws.count - holdoutStart

        print("")
        print("===================================")
        print("🎯 EURO-RECENCY / GAP HOLDOUT-TEST")
        print("===================================")
        print("Holdout-Ziehungen : \(holdoutCount)")
        print("Recency 20        : letzte 20 Ziehungen")
        print("Recency 50        : letzte 50 Ziehungen")
        print("Gap               : längster Abstand")
        print("Auswahl           : jeweils 2 Eurozahlen")
        print("Monte-Carlo       : \(monteCarloRuns)")
        print("")

        let recency20Model = evaluateSignal(
            name: "RECENCY 20",
            draws: draws,
            holdoutStart: holdoutStart,
            window: recency20Window,
            mode: .recency
        )

        let recency50Model = evaluateSignal(
            name: "RECENCY 50",
            draws: draws,
            holdoutStart: holdoutStart,
            window: recency50Window,
            mode: .recency
        )

        let gapModel = evaluateSignal(
            name: "GAP",
            draws: draws,
            holdoutStart: holdoutStart,
            window: 0,
            mode: .gap
        )

        let randomResults = randomBenchmark(
            draws: draws,
            holdoutStart: holdoutStart
        )

        print("")
        print("-----------------------------------")
        print("ERGEBNISSE")
        print("-----------------------------------")

        printResult(
            name: "Recency 20",
            modelAverage: recency20Model,
            randomResults: randomResults
        )

        printResult(
            name: "Recency 50",
            modelAverage: recency50Model,
            randomResults: randomResults
        )

        printResult(
            name: "Gap",
            modelAverage: gapModel,
            randomResults: randomResults
        )

        print("")
        print("Theorie Euro      : \(String(format: "%.4f", theoreticalExpectation(draws: draws, holdoutStart: holdoutStart)))")
        print("")
        print("Interpretation:")
        print("- Positives Δ bedeutet Vorteil gegenüber Zufall.")
        print("- Negatives Δ bedeutet schlechter als Zufall.")
        print("- Das Holdout wird weder zur Auswahl noch zur Optimierung verwendet.")
        print("- Die drei Signale werden vollständig getrennt bewertet.")
        print("- Erst ein positives Signal wird anschließend weiter untersucht.")
        print("")
        print(
            String(
                format: "⏱ Euro-Recency/Gap-Diagnostic: %.2f Sekunden",
                Date().timeIntervalSince(start)
            )
        )
        print("===================================")
    }

    // MARK: - Signal Evaluation

    private enum SignalMode {
        case recency
        case gap
    }

    private func evaluateSignal(
        name: String,
        draws: [EuroJackpotDraw],
        holdoutStart: Int,
        window: Int,
        mode: SignalMode
    ) -> Double {

        var totalHits = 0
        var totalTests = 0

        for index in holdoutStart..<draws.count {

            let trainingDraws = Array(draws.prefix(index))
            let targetDraw = draws[index]

            let maximumEuro =
                targetDraw.date < euroFormatCutoverDate()
                ? 10
                : 12

            let selected = selectEuroNumbers(
                trainingDraws: trainingDraws,
                maximumEuro: maximumEuro,
                window: window,
                mode: mode
            )

            totalHits += commonHitCount(
                selected,
                targetDraw.euroNumbers
            )

            totalTests += 1
        }

        guard totalTests > 0 else {
            return 0
        }

        let average = Double(totalHits) / Double(totalTests)

        print(
            String(
                format: "%-15@ Modell: %.4f",
                name,
                average
            )
        )

        return average
    }

    private func selectEuroNumbers(
        trainingDraws: [EuroJackpotDraw],
        maximumEuro: Int,
        window: Int,
        mode: SignalMode
    ) -> [Int] {

        guard maximumEuro >= 2 else {
            return []
        }

        switch mode {

        case .recency:

            let recentDraws =
                Array(
                    trainingDraws.suffix(
                        min(window, trainingDraws.count)
                    )
                )

            var counts: [Int: Int] = [:]

            for number in 1...maximumEuro {
                counts[number] = 0
            }

            for draw in recentDraws {

                for euroNumber in draw.euroNumbers {

                    guard euroNumber <= maximumEuro else {
                        continue
                    }

                    counts[euroNumber, default: 0] += 1
                }
            }

            return (1...maximumEuro)
                .sorted {
                    let lhs = counts[$0] ?? 0
                    let rhs = counts[$1] ?? 0

                    if lhs == rhs {
                        return $0 < $1
                    }

                    return lhs > rhs
                }
                .prefix(2)
                .map { $0 }

        case .gap:

            var lastSeen: [Int: Int] = [:]

            for number in 1...maximumEuro {
                lastSeen[number] = -1
            }

            for (drawIndex, draw) in trainingDraws.enumerated() {

                for euroNumber in draw.euroNumbers {

                    guard euroNumber <= maximumEuro else {
                        continue
                    }

                    lastSeen[euroNumber] = drawIndex
                }
            }

            let latestIndex = trainingDraws.count - 1

            return (1...maximumEuro)
                .sorted {
                    let lhsLast = lastSeen[$0] ?? -1
                    let rhsLast = lastSeen[$1] ?? -1

                    let lhsGap =
                        lhsLast < 0
                        ? latestIndex + 1
                        : latestIndex - lhsLast

                    let rhsGap =
                        rhsLast < 0
                        ? latestIndex + 1
                        : latestIndex - rhsLast

                    if lhsGap == rhsGap {
                        return $0 < $1
                    }

                    return lhsGap > rhsGap
                }
                .prefix(2)
                .map { $0 }
        }
    }

    // MARK: - Random Benchmark

    private func randomBenchmark(
        draws: [EuroJackpotDraw],
        holdoutStart: Int
    ) -> [Double] {

        var results: [Double] = []
        results.reserveCapacity(monteCarloRuns)

        for run in 0..<monteCarloRuns {

            let rng = SeededEuroRandomGenerator(
                seed: 0xEE_7600_0000 &+ UInt64(run)
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

                while selected.count < 2 {

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

            guard tickets > 0 else {
                continue
            }

            results.append(
                Double(hits) / Double(tickets)
            )
        }

        return results
    }

    // MARK: - Output

    private func printResult(
        name: String,
        modelAverage: Double,
        randomResults: [Double]
    ) {

        guard !randomResults.isEmpty else {
            print("\(name): kein Zufallsbenchmark")
            return
        }

        let randomAverage = mean(randomResults)

        let deltas = randomResults.map {
            modelAverage - $0
        }

        let delta = mean(deltas)
        let confidenceInterval =
            pairedConfidenceInterval(deltas)

        print(
            String(
                format:
                    "%-15@ Modell %.4f | Zufall %.4f | Δ %+.4f | 95%% CI ±%.4f",
                name,
                modelAverage,
                randomAverage,
                delta,
                confidenceInterval
            )
        )
    }

    // MARK: - Helpers

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

        let standardError =
            sqrt(variance)
            / sqrt(Double(values.count))

        return 1.96 * standardError
    }

    private func theoreticalExpectation(
        draws: [EuroJackpotDraw],
        holdoutStart: Int
    ) -> Double {

        guard holdoutStart < draws.count else {
            return 0
        }

        let values =
            draws[holdoutStart..<draws.count].map {
                draw -> Double in

                draw.date < euroFormatCutoverDate()
                    ? 0.4
                    : 1.0 / 3.0
            }

        return mean(values)
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

// MARK: - Deterministic Random Generator

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
