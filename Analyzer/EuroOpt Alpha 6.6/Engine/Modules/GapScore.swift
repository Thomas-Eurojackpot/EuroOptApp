//
//  GapScore.swift
//  EuroOpt
//
//  Alpha 6.4
//

import Foundation

final class GapScore: ScoreModule {

    // MARK: - Properties

    private let analyzer = GapAnalyzer()

    private var cachedDrawCount = -1
    private var cachedDistribution: [String: Int] = [:]
    private var cachedMaximum = 0

    // MARK: - Public Methods

    @inline(__always)
    func calculate(
        numbers: [Int],
        euroNumbers: [Int],
        draws: [EuroJackpotDraw]
    ) -> Double {

        if cachedDrawCount != draws.count {

            cachedDrawCount = draws.count

            cachedDistribution = analyzer.distribution(in: draws)
            cachedMaximum = cachedDistribution.values.max() ?? 0

        }

        guard cachedMaximum > 0 else {
            return 0
        }

        let sorted = numbers.sorted()

        var key = ""

        for index in 1..<sorted.count {

            if index > 1 {
                key.append("-")
            }

            key.append(String(sorted[index] - sorted[index - 1]))

        }

        let count = cachedDistribution[key] ?? 0

        return Double(count) / Double(cachedMaximum) * 100.0

    }

}
