//
//  FrequencyScore.swift
//  EuroOpt
//
//  Alpha 7.1
//

import Foundation

final class FrequencyScore: ScoreModule {

    // MARK: - Properties

    private let analyzer = FrequencyAnalyzer()

    private var cachedDrawCount = -1
    private var cachedFrequencies: [Int: Int] = [:]
    private var cachedMinimum = 0
    private var cachedMaximum = 0

    // Neuer Analyse-Cache (für V2)
    private let analysisEngine = AnalysisEngine()
    private var analysisData: AnalysisData?

    // MARK: - Public Methods

    @inline(__always)
    func calculate(
        numbers: [Int],
        euroNumbers: [Int],
        draws: [EuroJackpotDraw]
    ) -> Double {

        // Analyse nur einmal je Historie erzeugen
        if cachedDrawCount != draws.count {

            cachedDrawCount = draws.count

            analysisData = analysisEngine.build(
                from: draws
            )

            cachedFrequencies =
                analysisData?.frequencies ?? [:]

            cachedMinimum =
                analysisData?.minimumFrequency ?? 0

            cachedMaximum =
                analysisData?.maximumFrequency ?? 0

        }

        guard cachedMaximum > cachedMinimum else {
            return 0
        }

        var totalFrequency = 0

        for number in numbers {

            totalFrequency +=
                cachedFrequencies[number] ?? cachedMinimum

        }

        let minimumScore =
            cachedMinimum * numbers.count

        let maximumScore =
            cachedMaximum * numbers.count

        return Double(totalFrequency - minimumScore)
            / Double(maximumScore - minimumScore)
            * 100.0

    }

}
