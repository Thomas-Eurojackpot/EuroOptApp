//
//  FrequencyScore.swift
//  EuroOpt
//
//  Alpha 6.5
//

import Foundation

final class FrequencyScore: ScoreModule {

    // MARK: - Properties

    private let analyzer = FrequencyAnalyzer()

    // MARK: - Public Methods

    @inline(__always)
    func calculate(
        numbers: [Int],
        euroNumbers: [Int],
        draws: [EuroJackpotDraw]
    ) -> Double {

        let frequencies = analyzer.frequency(of: draws)

        guard
            let minimum = frequencies.values.min(),
            let maximum = frequencies.values.max(),
            maximum > minimum
        else {
            return 0
        }

        var total = 0

        for number in numbers {
            total += frequencies[number] ?? minimum
        }

        let minimumScore = minimum * numbers.count
        let maximumScore = maximum * numbers.count

        return Double(total - minimumScore)
            / Double(maximumScore - minimumScore)
            * 100.0

    }

}
