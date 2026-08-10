//
//  FrequencyScore.swift
//  EuroOpt
//
//  Alpha 6.4
//

import Foundation

final class FrequencyScore: ScoreModule {

    // MARK: - Properties

    private let analyzer = FrequencyAnalyzer()

    private var cachedDrawCount = -1
    private var cachedFrequencies: [Int: Int] = [:]
    private var cachedMinimum = 0
    private var cachedMaximum = 0

    // MARK: - Public Methods

    @inline(__always)
    func calculate(
        numbers: [Int],
        euroNumbers: [Int],
        draws: [EuroJackpotDraw]
    ) -> Double {

        if draws.count != cachedDrawCount {

            cachedDrawCount = draws.count

            cachedFrequencies = analyzer.frequency(of: draws)

            cachedMinimum = cachedFrequencies.values.min() ?? 0
            cachedMaximum = cachedFrequencies.values.max() ?? 0
        }

        guard cachedMaximum > cachedMinimum else {
            return 0
        }

        var totalFrequency = 0

        for number in numbers {
            totalFrequency += cachedFrequencies[number] ?? cachedMinimum
        }

        let minimumScore = cachedMinimum * numbers.count
        let maximumScore = cachedMaximum * numbers.count

        return Double(totalFrequency - minimumScore)
            / Double(maximumScore - minimumScore)
            * 100.0

    }

}
