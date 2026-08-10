//
//  AnalysisEngine.swift
//  EuroOpt
//
//  Alpha 7.1
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

        // MARK: - Frequenzen

        for number in draw.numbers {

            data.frequencies[number, default: 0] += 1

        }

        data.minimumFrequency =
            data.frequencies.values.min() ?? 0

        data.maximumFrequency =
            data.frequencies.values.max() ?? 0

        // MARK: - Paare

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

        // MARK: - Gerade / Ungerade

        let even = numbers.filter {
            $0.isMultiple(of: 2)
        }.count

        let odd = numbers.count - even

        data.evenOddDistribution["\(even):\(odd)", default: 0] += 1

        // MARK: - Hoch / Niedrig

        let high = numbers.filter {
            $0 > 25
        }.count

        let low = numbers.count - high

        data.highLowDistribution["\(high):\(low)", default: 0] += 1

        // MARK: - Summen

        let sum = numbers.reduce(0, +)

        data.sumDistribution[sum, default: 0] += 1

        // MARK: - Kleine Abstände

        var smallGaps = 0

        for i in 1..<numbers.count {

            if numbers[i] - numbers[i - 1] <= 2 {

                smallGaps += 1

            }

        }

        data.gapDistribution[smallGaps, default: 0] += 1

    }

}
