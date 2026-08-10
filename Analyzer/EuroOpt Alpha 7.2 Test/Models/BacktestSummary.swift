//
//  BacktestSummary.swift
//  EuroOpt
//
//  Alpha 6.6
//

import Foundation

struct BacktestSummary {

    let totalTests: Int
    let duration: Double

    let averageHits: Double
    let averageEuroHits: Double
    let averageEQI: Double

    let bestHits: Int
    let bestEuroHits: Int

    let hit0: Int
    let hit1: Int
    let hit2: Int
    let hit3: Int
    let hit4: Int
    let hit5: Int

    let euroHit0: Int
    let euroHit1: Int
    let euroHit2: Int

    let prizeClasses: [PrizeClassStatistics]

}
