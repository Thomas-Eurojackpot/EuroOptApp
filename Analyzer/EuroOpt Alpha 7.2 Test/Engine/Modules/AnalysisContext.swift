//
//  AnalysisContext.swift
//  EuroOpt
//
//  Alpha 7.4
//

import Foundation

final class AnalysisContext {

    // MARK: - Frequenzen

    private(set) var frequencies: [Int: Int]

    // MARK: - Paare

    private(set) var pairFrequencies: [Set<Int>: Int]

    // MARK: - Statistiken

    private(set) var minimumFrequency = 0
    private(set) var maximumFrequency = 0
    private(set) var maximumPairFrequency = 0

    // MARK: - Initialisierung

    init(draws: [EuroJackpotDraw]) {

        frequencies = Dictionary(
            uniqueKeysWithValues: (1...50).map { ($0, 0) }
        )

        pairFrequencies = [:]
        pairFrequencies.reserveCapacity(1500)

        for draw in draws {
            add(draw: draw)
        }

        updateStatistics()

    }

    // MARK: - Ziehung hinzufügen

    func add(draw: EuroJackpotDraw) {

        // Frequenzen

        for number in draw.numbers {
            frequencies[number, default: 0] += 1
        }

        // Paare (10 Kombinationen)

        let n = draw.numbers

        pairFrequencies[[n[0], n[1]], default: 0] += 1
        pairFrequencies[[n[0], n[2]], default: 0] += 1
        pairFrequencies[[n[0], n[3]], default: 0] += 1
        pairFrequencies[[n[0], n[4]], default: 0] += 1

        pairFrequencies[[n[1], n[2]], default: 0] += 1
        pairFrequencies[[n[1], n[3]], default: 0] += 1
        pairFrequencies[[n[1], n[4]], default: 0] += 1

        pairFrequencies[[n[2], n[3]], default: 0] += 1
        pairFrequencies[[n[2], n[4]], default: 0] += 1

        pairFrequencies[[n[3], n[4]], default: 0] += 1

        updateStatistics()

    }

    // MARK: - Private

    private func updateStatistics() {

        minimumFrequency = frequencies.values.min() ?? 0
        maximumFrequency = frequencies.values.max() ?? 0
        maximumPairFrequency = pairFrequencies.values.max() ?? 0

    }

}
