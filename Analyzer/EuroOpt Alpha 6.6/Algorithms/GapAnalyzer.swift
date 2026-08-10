//
//  GapAnalyzer.swift
//  EuroOpt
//

import Foundation

final class GapAnalyzer {

    func distribution(
        in draws: [EuroJackpotDraw]
    ) -> [String: Int] {

        var distribution: [String: Int] = [:]

        for draw in draws {

            let sorted = draw.numbers.sorted()

            let gaps = zip(sorted, sorted.dropFirst())
                .map { $1 - $0 }

            let key = gaps
                .map(String.init)
                .joined(separator: "-")

            distribution[key, default: 0] += 1

        }

        return distribution

    }

}
