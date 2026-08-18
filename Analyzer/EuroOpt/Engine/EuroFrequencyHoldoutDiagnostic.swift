//
//  EuroFrequencyHoldoutDiagnostic.swift
//  EuroOpt
//
//  Isolierter Holdout-Test der historischen Eurozahl-Häufigkeit
//

import Foundation

final class EuroFrequencyHoldoutDiagnostic {

    private let monteCarloRuns = 200

    func run(draws: [EuroJackpotDraw]) {

        guard draws.count > 140 else {
            print("❌ Euro-Frequency-Diagnostic: zu wenige Ziehungen")
            return
        }

        let start = Date()

        let totalTests = draws.count - 100
        let validationTests = totalTests / 2
        let holdoutStart = 100 + validationTests
        let holdoutCount = draws.count - holdoutStart

        var modelHits = 0
        var modelTickets = 0

        for index in holdoutStart..<draws.count {

            let trainingDraws = Array(draws.prefix(index))
            let targetDraw = draws[index]

            let euroMaximum =
                targetDraw.date < euroFormatCutoverDate()
                ? 10
                : 12

            let frequencies = EuroFrequencyAnalyzer()
                .frequency(of: trainingDraws)

            let ranked = (1...euroMaximum).sorted {
                let lhs = frequencies[$0] ?? 0
                let rhs = frequencies[$1] ?? 0

                if lhs == rhs {
                    return $0 < $1
                }

                return lhs > rhs
            }

            guard ranked.count >= 2 else {
                continue
            }

            let selectedEuroNumbers = Array(ranked.prefix(2))

            modelHits += commonHitCount(
                selectedEuroNumbers,
                targetDraw.euroNumbers
            )

            modelTickets += 1
        }

        guard modelTickets > 0 else {
            print("❌ Euro-Frequency-Diagnostic: kein Holdout vorhanden")
            return
        }

        let modelAverage =
            Double(modelHits) / Double(modelTickets)

        var randomAverages: [Double] = []
        randomAverages.reserveCapacity(monteCarloRuns)

        for run in 0..<monteCarloRuns {

            let rng = SeededEuroRandomGenerator(
                seed: 0xEF_0000_7500 &+ UInt64(run)
            )

            var randomHits = 0
            var randomTickets = 0

            for index in holdoutStart..<draws.count {

                let targetDraw = draws[index]

                let euroMaximum =
                    targetDraw.date < euroFormatCutoverDate()
                    ? 10
                    : 12

                var euroNumbers: [Int] = []

                while euroNumbers.count < 2 {
                    let value =
                        rng.nextInt(upperBound: euroMaximum) + 1

                    if !euroNumbers.contains(value) {
                        euroNumbers.append(value)
                    }
                }

                randomHits += commonHitCount(
                    euroNumbers,
                    targetDraw.euroNumbers
                )

                randomTickets += 1
            }

            guard randomTickets > 0 else {
                continue
            }

            randomAverages.append(
                Double(randomHits) / Double(randomTickets)
            )
        }

        guard !randomAverages.isEmpty else {
            print("❌ Euro-Frequency-Diagnostic: kein Zufallsbenchmark")
            return
        }

        let randomAverage = mean(randomAverages)

        let deltas = randomAverages.map {
            modelAverage - $0
        }

        let delta = mean(deltas)
        let confidenceInterval = pairedConfidenceInterval(deltas)

        let theoreticalExpectation =
            draws[holdoutStart..<draws.count].reduce(0.0) {
                partial,
                draw in

                partial +
                (
                    draw.date < euroFormatCutoverDate()
                    ? 0.4
                    : 1.0 / 3.0
                )
            }
            / Double(holdoutCount)

        print("")
        print("===================================")
        print("🎯 EURO-FREQUENCY HOLDOUT-TEST")
        print("===================================")
        print("Holdout-Ziehungen : \(holdoutCount)")
        print("Modell            : 2 historisch häufigste Eurozahlen")
        print("Monte-Carlo       : \(monteCarloRuns)")
        print("")
        print(String(format: "Ø Modell Euro     : %.4f", modelAverage))
        print(String(format: "Ø Zufall Euro     : %.4f", randomAverage))
        print(String(format: "Δ Modell - Zufall : %+.4f", delta))
        print(String(format: "95%% CI Δ          : ±%.4f", confidenceInterval))
        print("")
        print(String(format: "Theorie Euro      : %.4f", theoreticalExpectation))
        print("")
        print("Interpretation:")
        print("- Positives Δ bedeutet Vorteil gegenüber Zufall.")
        print("- Schließt das 95-%-KI die 0 nicht ein, ist der Unterschied im Benchmark stabil.")
        print("- Das Holdout wurde weder zur Auswahl noch zur Bewertung der historischen Häufigkeit verwendet.")
        print("")
        print(
            String(
                format: "⏱ Euro-Frequency-Diagnostic: %.2f Sekunden",
                Date().timeIntervalSince(start)
            )
        )
        print("===================================")
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

    private func mean(_ values: [Double]) -> Double {

        guard !values.isEmpty else {
            return 0
        }

        return values.reduce(0, +) / Double(values.count)
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

                partial + pow(value - average, 2)
            }
            / Double(values.count - 1)

        let standardError =
            sqrt(variance) / sqrt(Double(values.count))

        return 1.96 * standardError
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
    func nextInt(upperBound: Int) -> Int {

        guard upperBound > 0 else {
            return 0
        }

        return Int(
            nextUInt64() % UInt64(upperBound)
        )
    }
}
