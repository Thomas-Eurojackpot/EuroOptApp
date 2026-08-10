//
//  PairScore.swift
//  EuroOpt
//
//  Alpha 7.1
//

import Foundation

final class PairScore: ScoreModule {

    // MARK: - Properties

    private let analyzer = PairAnalyzer()

    private var cachedDrawCount = -1
    private var cachedStatistics: PairStatistics?

    // Neuer Analyse-Cache (V2)

    private let analysisEngine = AnalysisEngine()
    private var analysisData: AnalysisData?

    // MARK: - Public Methods

    @inline(__always)
    func calculate(
        numbers: [Int],
        euroNumbers: [Int],
        draws: [EuroJackpotDraw]
    ) -> Double {

        if cachedDrawCount != draws.count {

            cachedDrawCount = draws.count

            analysisData = analysisEngine.build(
                from: draws
            )

            cachedStatistics = PairStatistics(
                frequencies: analysisData?.pairFrequencies ?? [:],
                maximumFrequency: analysisData?.maximumPairFrequency ?? 0,
                averageFrequency: analysisData?.averagePairFrequency ?? 0
            )

        }

        guard
            let statistics = cachedStatistics,
            statistics.maximumFrequency > 0
        else {
            return 0
        }

        let sortedNumbers = numbers.sorted()

        var totalFrequency = 0

        for i in 0..<(sortedNumbers.count - 1) {

            let first = sortedNumbers[i]

            for j in (i + 1)..<sortedNumbers.count {

                let pair: Set<Int> = [
                    first,
                    sortedNumbers[j]
                ]

                totalFrequency +=
                    statistics.frequencies[pair] ?? 0

            }

        }

        return
            (Double(totalFrequency) / 10.0)
            / Double(statistics.maximumFrequency)
            * 100.0

    }

}
