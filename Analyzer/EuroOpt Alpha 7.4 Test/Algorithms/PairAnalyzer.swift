//
//  PairAnalyzer.swift
//  EuroOpt
//

import Foundation

final class PairAnalyzer {

    func analyze(draws: [EuroJackpotDraw]) -> PairStatistics {

        var frequencies: [Set<Int>: Int] = [:]

        for draw in draws {

            let numbers = draw.numbers.sorted()

            for i in 0..<numbers.count {

                for j in (i + 1)..<numbers.count {

                    let pair: Set<Int> = [
                        numbers[i],
                        numbers[j]
                    ]

                    frequencies[pair, default: 0] += 1

                }

            }

        }

        let maximumFrequency = frequencies.values.max() ?? 0

        let averageFrequency: Double

        if frequencies.isEmpty {

            averageFrequency = 0

        } else {

            averageFrequency =
                Double(frequencies.values.reduce(0, +)) /
                Double(frequencies.count)

        }

        return PairStatistics(
            frequencies: frequencies,
            maximumFrequency: maximumFrequency,
            averageFrequency: averageFrequency
        )

    }

}
