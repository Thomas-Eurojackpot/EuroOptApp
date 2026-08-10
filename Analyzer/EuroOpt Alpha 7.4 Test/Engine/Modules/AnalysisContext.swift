//
//  AnalysisContext.swift
//  EuroOpt
//
//  Alpha 6.6
//

import Foundation

final class AnalysisContext {

    // MARK: - Frequenzen

    private(set) var frequencies: [Int: Int] = [:]

    // MARK: - Paare

    private(set) var pairFrequencies: [Set<Int>: Int] = [:]

    // MARK: - Initialisierung

    init(draws: [EuroJackpotDraw]) {

        for number in 1...50 {
            frequencies[number] = 0
        }

        for draw in draws {
            add(draw: draw)
        }

    }

    // MARK: - Ziehung hinzufügen

    func add(draw: EuroJackpotDraw) {

        // Frequenzen

        for number in draw.numbers {
            frequencies[number, default: 0] += 1
        }

        // Paare

        let numbers = draw.numbers.sorted()

        for i in 0..<numbers.count {

            for j in (i + 1)..<numbers.count {

                let pair: Set<Int> = [
                    numbers[i],
                    numbers[j]
                ]

                pairFrequencies[pair, default: 0] += 1

            }

        }

    }

}
