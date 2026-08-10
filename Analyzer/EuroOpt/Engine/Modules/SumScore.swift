//
//  SumScore.swift
//  EuroOpt
//

import Foundation

final class SumScore: ScoreModule {

    // MARK: - Properties

    private let analyzer = SumAnalyzer()

    // MARK: - Public Methods

    func calculate(
        numbers: [Int],
        euroNumbers: [Int],
        draws: [EuroJackpotDraw]
    ) -> Double {

        let distribution = analyzer.distribution(in: draws)

        let sum = numbers.reduce(0, +)

        guard
            let maximum = distribution.values.max(),
            maximum > 0
        else {
            return 0
        }

        let count = distribution[sum] ?? 0

        return Double(count) / Double(maximum) * 100.0

    }

}
