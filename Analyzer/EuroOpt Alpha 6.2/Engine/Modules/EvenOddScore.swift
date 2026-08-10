//
//  EvenOddScore.swift
//  EuroOpt
//
//  Alpha 4.4
//

import Foundation

final class EvenOddScore: ScoreModule {

    // MARK: - Properties

    private let analyzer = EvenOddAnalyzer()

    // MARK: - Public Methods

    func calculate(
        numbers: [Int],
        euroNumbers: [Int],
        draws: [EuroJackpotDraw]
    ) -> Double {

        let distribution = analyzer.distribution(in: draws)

        let even = numbers.filter { $0.isMultiple(of: 2) }.count
        let odd = numbers.count - even

        let key = "\(even):\(odd)"

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
