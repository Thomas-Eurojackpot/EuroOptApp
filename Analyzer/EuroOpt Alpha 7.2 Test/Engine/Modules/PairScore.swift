//
//  PairScore.swift
//  EuroOpt
//
//  Alpha 7.4
//

import Foundation

final class PairScore: ScoreModule {

    @inline(__always)
    func calculate(
        numbers: [Int],
        euroNumbers: [Int],
        context: AnalysisContext
    ) -> Double {

        guard context.maximumPairFrequency > 0 else {
            return 0
        }

        var totalFrequency = 0

        totalFrequency += context.pairFrequencies[[numbers[0], numbers[1]]] ?? 0
        totalFrequency += context.pairFrequencies[[numbers[0], numbers[2]]] ?? 0
        totalFrequency += context.pairFrequencies[[numbers[0], numbers[3]]] ?? 0
        totalFrequency += context.pairFrequencies[[numbers[0], numbers[4]]] ?? 0

        totalFrequency += context.pairFrequencies[[numbers[1], numbers[2]]] ?? 0
        totalFrequency += context.pairFrequencies[[numbers[1], numbers[3]]] ?? 0
        totalFrequency += context.pairFrequencies[[numbers[1], numbers[4]]] ?? 0

        totalFrequency += context.pairFrequencies[[numbers[2], numbers[3]]] ?? 0
        totalFrequency += context.pairFrequencies[[numbers[2], numbers[4]]] ?? 0

        totalFrequency += context.pairFrequencies[[numbers[3], numbers[4]]] ?? 0

        return
            (Double(totalFrequency) / 10.0)
            / Double(context.maximumPairFrequency)
            * 100.0

    }

}
