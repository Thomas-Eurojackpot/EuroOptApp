//
//  PairScore.swift
//  EuroOpt
//

import Foundation

final class PairScore: ScoreModule {

    // MARK: - Properties

    private let analyzer = PairAnalyzer()

    // MARK: - Public Methods

    func calculate(
        numbers: [Int],
        euroNumbers: [Int],
        draws: [EuroJackpotDraw]
    ) -> Double {

        let statistics = analyzer.analyze(draws: draws)

        guard statistics.maximumFrequency > 0 else {
            return 0
        }

        var totalFrequency = 0

        let sortedNumbers = numbers.sorted()

        for i in 0..<sortedNumbers.count {

            for j in (i + 1)..<sortedNumbers.count {

                let pair: Set<Int> = [
                    sortedNumbers[i],
                    sortedNumbers[j]
                ]

                totalFrequency += statistics.frequencies[pair] ?? 0

            }

        }

        // Durchschnitt der 10 Zahlenpaare
        let averageFrequency = Double(totalFrequency) / 10.0

        let normalizedScore =
            averageFrequency /
            Double(statistics.maximumFrequency)

        return normalizedScore * 100.0

    }

}
