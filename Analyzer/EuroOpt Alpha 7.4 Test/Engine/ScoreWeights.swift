//
//  ScoreWeights.swift
//  EuroOpt
//
//  Alpha 7.0
//

import Foundation

struct ScoreWeights {

    var frequency: Double
    var pair: Double
    var evenOdd: Double
    var highLow: Double
    var sum: Double

    static let `default` = ScoreWeights(
        frequency: 0.30,
        pair: 0.25,
        evenOdd: 0.15,
        highLow: 0.15,
        sum: 0.15
    )

}
