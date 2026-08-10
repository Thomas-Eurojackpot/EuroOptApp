//
//  AppSettings.swift
//  EuroOpt
//
//  Alpha 6.2
//

import Foundation

enum AppSettings {

    // MARK: - Optimizer

    static let candidateCount = 100_000

    static let recommendationCount = 8

    // Wieder auf den ursprünglichen Wert
    static let hillClimbingIterations = 100

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
