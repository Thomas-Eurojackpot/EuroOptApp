//
//  AppSettings.swift
//  EuroOpt
//
//  Alpha 7.3
//

import Foundation

enum AppSettings {

    // MARK: - Optimizer

    /// Anzahl erzeugter Spielsysteme im normalen Optimizer
    static let candidateCount = 100_000

    /// Anzahl der auszugebenden Empfehlungen
    static let recommendationCount = 8

    /// Hill Climbing für normale Empfehlungen
    static let hillClimbingIterations = 60

    /// Abbruch nach X erfolglosen Versuchen
    static let earlyStopLimit = 12

    // MARK: - Backtest

    /// Deutlich schnellerer Backtest für Lernphase
    static let backtestCandidateCount = 250

    /// Hill Climbing im Backtest
    static let backtestHillClimbingIterations = 12

    /// Survivor nach QuickScore
    static let backtestSurvivorCount = 20

    // MARK: - Ticket Quality

    static let minimumSum = 90
    static let maximumSum = 180

    static let minimumEvenNumbers = 2
    static let maximumEvenNumbers = 3

    static let minimumHighNumbers = 2
    static let maximumHighNumbers = 3

    static let maximumSmallGaps = 1
    static let maximumConsecutiveNumbers = 2

}
