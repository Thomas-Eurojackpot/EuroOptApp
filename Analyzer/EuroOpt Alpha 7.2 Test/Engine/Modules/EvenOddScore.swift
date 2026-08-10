//
//  EvenOddScore.swift
//  EuroOpt
//
//  Alpha 7.4
//

import Foundation

final class EvenOddScore: ScoreModule {

    private let analyzer = EvenOddAnalyzer()

    private var cachedDistribution: [String: Int] = [:]
    private var cachedMaximum = 0

    func calculate(
        numbers: [Int],
        euroNumbers: [Int],
        context: AnalysisContext
    ) -> Double {

        if cachedDistribution.isEmpty {

            cachedDistribution = analyzer.distribution(
                in: context
            )

            cachedMaximum =
                cachedDistribution.values.max() ?? 0
        }

        guard cachedMaximum > 0 else {
            return 0
        }

        let even = numbers.filter {
            $0.isMultiple(of: 2)
        }.count

        let odd = numbers.count - even

        let key = "\(even):\(odd)"

        let count = cachedDistribution[key] ?? 0

        return Double(count)
            / Double(cachedMaximum)
            * 100.0

    }

}
