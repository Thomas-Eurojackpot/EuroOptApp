//
//  BacktestConfiguration.swift
//  EuroOpt
//
//  Alpha 7.3
//

import Foundation

struct BacktestConfiguration {

    let trainingDraws: Int
    let testDraws: Int
    let candidateCount: Int
    let recommendationCount: Int
    let hillClimbingIterations: Int

}

// MARK: - Vordefinierte Konfigurationen

extension BacktestConfiguration {

    static func normal(
        candidateCount: Int,
        recommendationCount: Int
    ) -> BacktestConfiguration {

        BacktestConfiguration(
            trainingDraws: 50,
            testDraws: 50,
            candidateCount: candidateCount,
            recommendationCount: recommendationCount,
            hillClimbingIterations: AppSettings.backtestHillClimbingIterations
        )

    }

    static func learning(
        recommendationCount: Int
    ) -> BacktestConfiguration {

        BacktestConfiguration(
            trainingDraws: 30,
            testDraws: 10,
            candidateCount: 200,
            recommendationCount: recommendationCount,
            hillClimbingIterations: 40
        )

    }

    static func research(
        recommendationCount: Int
    ) -> BacktestConfiguration {

        BacktestConfiguration(
            trainingDraws: 150,
            testDraws: 150,
            candidateCount: 5000,
            recommendationCount: recommendationCount,
            hillClimbingIterations: 500
        )

    }

}
