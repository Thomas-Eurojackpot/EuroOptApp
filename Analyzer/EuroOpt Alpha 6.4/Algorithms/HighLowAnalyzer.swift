//
//  HighLowAnalyzer.swift
//  EuroOpt
//

import Foundation

final class HighLowAnalyzer {

    func distribution(
        in draws: [EuroJackpotDraw]
    ) -> [String: Int] {

        var distribution: [String: Int] = [:]

        for draw in draws {

            let low = draw.numbers.filter { $0 <= 25 }.count
            let high = draw.numbers.count - low

            let key = "\(low):\(high)"

            distribution[key, default: 0] += 1

        }

        return distribution

    }

}
