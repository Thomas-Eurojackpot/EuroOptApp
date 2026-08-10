//
//  ScoreResult.swift
//  EuroOpt
//
//  Alpha 5.0
//

import Foundation

struct ScoreResult {

    // MARK: - Gesamtbewertung

    let totalScore: Double

    // MARK: - Kernmodule

    let frequencyScore: Double

    let pairScore: Double

    let evenOddScore: Double

    let highLowScore: Double

    let sumScore: Double

    // MARK: - EQI

    var eqi: EQI {

        EQI(value: totalScore)

    }

}
