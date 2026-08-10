//
//  AnalysisData.swift
//  EuroOpt
//
//  Alpha 7.0
//

import Foundation

struct AnalysisData {

    // MARK: - Frequenzen

    var frequencies: [Int: Int]

    var minimumFrequency: Int

    var maximumFrequency: Int

    // MARK: - Paare

    var pairFrequencies: [Set<Int>: Int]

    var maximumPairFrequency: Int

    var averagePairFrequency: Double

    // MARK: - Allgemein

    var drawCount: Int

    // MARK: - Initialisierung

    init() {

        frequencies = [:]

        for number in 1...50 {
            frequencies[number] = 0
        }

        minimumFrequency = 0
        maximumFrequency = 0

        pairFrequencies = [:]

        maximumPairFrequency = 0
        averagePairFrequency = 0

        drawCount = 0

    }

}
