//
//  AppSettings.swift
//  EuroOpt
//
//  Alpha 6.5
//

import Foundation

enum AppSettings {

    // MARK: - Optimizer

    /// Anzahl erzeugter Spielsysteme im normalen Optimizer
    static let candidateCount = 100_000

    /// Anzahl der auszugebenden Empfehlungen
    static let recommendationCount = 8

    /// Maximale Hill-Climbing-Durchläufe
    static let hillClimbingIterations = 60

    /// Abbruch nach X erfolglosen Versuchen
    static let earlyStopLimit = 12

    // MARK: - Backtest

    /// Reduzierte Kandidatenzahl für schnellere Backtests
    static let backtestCandidateCount = 500

    /// Reduzierte Hill-Climbing-Iterationen
    static let backtestHillClimbingIterations = 30

    /// Anzahl der Survivor nach dem QuickScore
    static let backtestSurvivorCount = 40

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
