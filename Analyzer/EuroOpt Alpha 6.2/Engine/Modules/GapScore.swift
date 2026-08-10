//
//  GapScore.swift
//  EuroOpt
//

import Foundation

final class GapScore: ScoreModule {

    // MARK: - Properties

    private let analyzer = GapAnalyzer()

    // MARK: - Public Methods

    func calculate(
        numbers: [Int],
        euroNumbers: [Int],
        draws: [EuroJackpotDraw]
    ) -> Double {

        let distribution = analyzer.distribution(in: draws)

        let sorted = numbers.sorted()

        let gaps = zip(sorted, sorted.dropFirst())
            .map { $1 - $0 }

        let key = gaps
            .map(String.init)
            .joined(separator: "-")

        guard
            let maximum = distribution.values.max(),
            maximum > 0
        else {
            return 0
        }

        let count = distribution[key] ?? 0

        return Double(count) / Double(maximum) * 100.0

    }

}
