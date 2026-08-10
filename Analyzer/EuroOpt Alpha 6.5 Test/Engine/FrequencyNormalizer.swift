//
//  FrequencyNormalizer.swift
//  EuroOpt
//
//  Alpha 6.4
//

import Foundation

final class FrequencyNormalizer {

    @inline(__always)
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

        var total = 0

        for number in numbers {
            total += frequencies[number] ?? minimum
        }

        let minScore = minimum * numbers.count
        let range = maximum - minimum

        guard range > 0 else {
            return 0
        }

        return Double(total - minScore)
            / Double(range * numbers.count)
            * 100.0

    }

}
