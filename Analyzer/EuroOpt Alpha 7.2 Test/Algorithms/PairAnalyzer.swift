//
//  PairAnalyzer.swift
//  EuroOpt
//
//  Alpha 7.4
//

import Foundation

final class PairAnalyzer {

    func analyze(draws: [EuroJackpotDraw]) -> PairStatistics {

        var frequencies: [Set<Int>: Int] = [:]
        frequencies.reserveCapacity(1500)

        for draw in draws {

            let n = draw.numbers

            frequencies[[n[0], n[1]], default: 0] += 1
            frequencies[[n[0], n[2]], default: 0] += 1
            frequencies[[n[0], n[3]], default: 0] += 1
            frequencies[[n[0], n[4]], default: 0] += 1

            frequencies[[n[1], n[2]], default: 0] += 1
            frequencies[[n[1], n[3]], default: 0] += 1
            frequencies[[n[1], n[4]], default: 0] += 1

            frequencies[[n[2], n[3]], default: 0] += 1
            frequencies[[n[2], n[4]], default: 0] += 1

            frequencies[[n[3], n[4]], default: 0] += 1
        }

        let maximumFrequency = frequencies.values.max() ?? 0

        let averageFrequency: Double

        if frequencies.isEmpty {

            averageFrequency = 0

        } else {

            averageFrequency =
                Double(frequencies.values.reduce(0, +))
                / Double(frequencies.count)

        }

        return PairStatistics(
            frequencies: frequencies,
            maximumFrequency: maximumFrequency,
            averageFrequency: averageFrequency
        )

    }

}
