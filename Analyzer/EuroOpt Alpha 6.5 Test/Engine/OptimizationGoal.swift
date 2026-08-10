//
//  OptimizationGoal.swift
//  EuroOpt
//

import Foundation

struct OptimizationGoal {

    // MARK: - EQI Gewichtung

    var frequencyWeight: Double = 30

    var pairWeight: Double = 25

    var evenOddWeight: Double = 15

    var highLowWeight: Double = 15

    var sumWeight: Double = 15

    // Neue Kriterien zunächst nur berechnen,
    // aber noch nicht in den EQI einfließen lassen.

    var gapWeight: Double = 0

}
