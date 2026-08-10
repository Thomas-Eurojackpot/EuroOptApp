//
//  EuroFrequencyScore.swift
//  EuroOpt
//

import Foundation

final class EuroFrequencyScore: ScoreModule {

    // MARK: - Properties

    private let analyzer = EuroFrequencyAnalyzer()

    // MARK: - Public Methods

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

        let totalFrequency = euroNumbers.reduce(0) { result, number in
            result + (frequencies[number] ?? minimum)
        }

        let minimumScore = minimum * euroNumbers.count
        let maximumScore = maximum * euroNumbers.count

        let normalizedScore =
            Double(totalFrequency - minimumScore) /
            Double(maximumScore - minimumScore)

        return normalizedScore * 100.0

    }

}
