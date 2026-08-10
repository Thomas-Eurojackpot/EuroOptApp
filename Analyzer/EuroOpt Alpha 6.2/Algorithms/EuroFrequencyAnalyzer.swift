//
//  EuroFrequencyAnalyzer.swift
//  EuroOpt
//

import Foundation

final class EuroFrequencyAnalyzer {

    func frequency(
        of draws: [EuroJackpotDraw]
    ) -> [Int: Int] {

        var counter: [Int: Int] = [:]

        for number in 1...12 {
            counter[number] = 0
        }

        for draw in draws {

            for euroNumber in draw.euroNumbers {

                counter[euroNumber, default: 0] += 1

            }

        }

        return counter

    }

}
