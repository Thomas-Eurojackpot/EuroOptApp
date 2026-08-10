//
//  GapScore.swift
//  EuroOpt
//
//  Alpha 6.5
//

import Foundation

final class GapScore: ScoreModule {

    // MARK: - Properties

    private let analyzer = GapAnalyzer()

    // MARK: - Public Methods

    @inline(__always)
    func calculate(
        numbers: [Int],
        euroNumbers: [Int],
        draws: [EuroJackpotDraw]
    ) -> Double {

        let distribution = analyzer.distribution(in: draws)

        guard
            let maximum = distribution.values.max(),
            maximum > 0
        else {
            return 0
        }

        let sorted = numbers.sorted()

        var key = ""
        key.reserveCapacity(12)

        for index in 1..<sorted.count {

            if index > 1 {
                key.append("-")
            }

            key.append(String(sorted[index] - sorted[index - 1]))

        }

        let count = distribution[key] ?? 0

        return Double(count) / Double(maximum) * 100.0

    }

}
