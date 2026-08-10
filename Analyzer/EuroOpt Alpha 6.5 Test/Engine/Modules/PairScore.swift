//
//  PairScore.swift
//  EuroOpt
//
//  Alpha 6.5
//

import Foundation

final class PairScore: ScoreModule {

    // MARK: - Properties

    private let analyzer = PairAnalyzer()

    // MARK: - Public Methods

    @inline(__always)
    func calculate(
        numbers: [Int],
        euroNumbers: [Int],
        draws: [EuroJackpotDraw]
    ) -> Double {

        let statistics = analyzer.analyze(draws: draws)

        guard statistics.maximumFrequency > 0 else {
            return 0
        }

        let sortedNumbers = numbers.sorted()

        var totalFrequency = 0

        for i in 0..<(sortedNumbers.count - 1) {

            let first = sortedNumbers[i]

            for j in (i + 1)..<sortedNumbers.count {

                let pair: Set<Int> = [first, sortedNumbers[j]]

                totalFrequency +=
                    statistics.frequencies[pair] ?? 0

            }

        }

        return
            (Double(totalFrequency) / 10.0)
            / Double(statistics.maximumFrequency)
            * 100.0

    }

}
