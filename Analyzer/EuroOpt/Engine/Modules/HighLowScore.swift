//
//  HighLowScore.swift
//  EuroOpt
//

import Foundation

final class HighLowScore: ScoreModule {

    // MARK: - Properties

    private let analyzer = HighLowAnalyzer()

    // MARK: - Public Methods

    func calculate(
        numbers: [Int],
        euroNumbers: [Int],
        draws: [EuroJackpotDraw]
    ) -> Double {

        let distribution = analyzer.distribution(in: draws)

        let low = numbers.filter { $0 <= 25 }.count
        let high = numbers.count - low

        let key = "\(low):\(high)"

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
