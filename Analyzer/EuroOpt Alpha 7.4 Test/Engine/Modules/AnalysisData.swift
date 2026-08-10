//
//  AnalysisData.swift
//  EuroOpt
//
//  Alpha 7.1
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

    // MARK: - Verteilungen

    var evenOddDistribution: [String: Int]

    var highLowDistribution: [String: Int]

    var sumDistribution: [Int: Int]

    var gapDistribution: [Int: Int]

    // MARK: - Allgemein

    var drawCount: Int

    // MARK: - Initialisierung

    init() {

        // Frequenzen

        frequencies = [:]

        for number in 1...50 {
            frequencies[number] = 0
        }

        minimumFrequency = 0
        maximumFrequency = 0

        // Paare

        pairFrequencies = [:]
        maximumPairFrequency = 0
        averagePairFrequency = 0

        // Verteilungen

        evenOddDistribution = [:]
        highLowDistribution = [:]
        sumDistribution = [:]
        gapDistribution = [:]

        // Allgemein

        drawCount = 0

    }

}
