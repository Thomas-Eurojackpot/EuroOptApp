//
//  FrequencyNormalizer.swift
//  EuroOpt
//
//  Alpha 2.6
//

import Foundation

final class FrequencyNormalizer {

    func score(
        numbers: [Int],
        frequencies: [Int: Int]
    ) -> Double {

        guard
            let minimum = frequencies.values.min(),
            let maximum = frequencies.values.max(),
            maximum > minimum
        else {
            return 0
        }

        let total = numbers.reduce(0) { partialResult, number in
            partialResult + (frequencies[number] ?? minimum)
        }

        let minScore = minimum * numbers.count
        let maxScore = maximum * numbers.count

        let normalized = Double(total - minScore) /
            Double(maxScore - minScore)

        return normalized * 100.0

    }

}
