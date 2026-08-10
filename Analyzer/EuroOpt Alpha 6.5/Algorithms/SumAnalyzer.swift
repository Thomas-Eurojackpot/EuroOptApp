//
//  SumAnalyzer.swift
//  EuroOpt
//

import Foundation

final class SumAnalyzer {

    func distribution(
        in draws: [EuroJackpotDraw]
    ) -> [Int: Int] {

        var distribution: [Int: Int] = [:]

        for draw in draws {

            let sum = draw.numbers.reduce(0, +)

            distribution[sum, default: 0] += 1

        }

        return distribution

    }

}
