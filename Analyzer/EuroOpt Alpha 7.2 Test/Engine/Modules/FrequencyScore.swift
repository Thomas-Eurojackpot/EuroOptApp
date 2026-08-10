//
//  FrequencyScore.swift
//  EuroOpt
//
//  Alpha 7.4
//

import Foundation

final class FrequencyScore: ScoreModule {

    @inline(__always)
    func calculate(
        numbers: [Int],
        euroNumbers: [Int],
        context: AnalysisContext
    ) -> Double {

        guard
            context.maximumFrequency > context.minimumFrequency
        else {
            return 0
        }

        var totalFrequency = 0

        for number in numbers {
            totalFrequency +=
                context.frequencies[number]
                ?? context.minimumFrequency
        }

        let minimumScore =
            context.minimumFrequency * numbers.count

        let maximumScore =
            context.maximumFrequency * numbers.count

        return Double(totalFrequency - minimumScore)
            / Double(maximumScore - minimumScore)
            * 100.0

    }

}
