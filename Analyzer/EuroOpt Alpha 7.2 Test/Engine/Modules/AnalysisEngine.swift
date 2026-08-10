//
//  AnalysisEngine.swift
//  EuroOpt
//
//  Alpha 7.0
//

import Foundation

final class AnalysisEngine {

    // MARK: - Public

    func build(
        from draws: [EuroJackpotDraw]
    ) -> AnalysisData {

        var data = AnalysisData()

        for draw in draws {

            add(
                draw: draw,
                to: &data
            )

        }

        return data

    }

    func add(
        draw: EuroJackpotDraw,
        to data: inout AnalysisData
    ) {

        data.drawCount += 1

        // Frequenzen

        for number in draw.numbers {

            data.frequencies[number, default: 0] += 1

        }

        data.minimumFrequency =
            data.frequencies.values.min() ?? 0

        data.maximumFrequency =
            data.frequencies.values.max() ?? 0

        // Paare

        let numbers = draw.numbers.sorted()

        for i in 0..<numbers.count {

            for j in (i + 1)..<numbers.count {

                let pair: Set<Int> = [
                    numbers[i],
                    numbers[j]
                ]

                data.pairFrequencies[pair, default: 0] += 1

            }

        }

        data.maximumPairFrequency =
            data.pairFrequencies.values.max() ?? 0

        if !data.pairFrequencies.isEmpty {

            data.averagePairFrequency =
                Double(data.pairFrequencies.values.reduce(0, +))
                / Double(data.pairFrequencies.count)

        }

    }

}
