//
//  NewMoonAnalyzer.swift
//  EuroOpt
//
//  Isolated new-moon analysis.
//  This component does not modify Alpha 7.5, scoring, weights, or ticket generation.
//

import Foundation

final class NewMoonAnalyzer {

    enum Category: String, CaseIterable {
        case exactDay = "Neumond-Tag"
        case plusMinus1 = "±1 Tag"
        case plusMinus2 = "±2 Tage"
        case plusMinus3 = "±3 Tage"
        case farther = ">3 Tage"
    }

    struct Result {
        let drawDate: Date
        let nearestNewMoon: Date
        let distanceDays: Double
        let category: Category
    }

    // Meeus-style simple synodic approximation.
    // J2000 reference new moon: 2000-01-06 18:14 UTC.
    private let referenceNewMoon = 2451550.25972
    private let synodicMonth = 29.530588853

    func analyze(draws: [EuroJackpotDraw]) -> [Result] {
        draws.map { analyze(date: $0.date) }
    }

    func analyze(date: Date) -> Result {
        let julianDay = date.timeIntervalSince1970 / 86400.0 + 2440587.5
        let cycles = (julianDay - referenceNewMoon) / synodicMonth
        let nearestCycle = cycles.rounded()
        let nearestJulianDay = referenceNewMoon + nearestCycle * synodicMonth
        let distanceDays = abs(julianDay - nearestJulianDay)
        let nearestDate = Date(timeIntervalSince1970: (nearestJulianDay - 2440587.5) * 86400.0)

        let category: Category
        switch distanceDays {
        case ..<0.5:
            category = .exactDay
        case ..<1.5:
            category = .plusMinus1
        case ..<2.5:
            category = .plusMinus2
        case ..<3.5:
            category = .plusMinus3
        default:
            category = .farther
        }

        return Result(
            drawDate: date,
            nearestNewMoon: nearestDate,
            distanceDays: distanceDays,
            category: category
        )
    }

    func categoryCounts(draws: [EuroJackpotDraw]) -> [Category: Int] {
        analyze(draws: draws).reduce(into: [:]) { counts, result in
            counts[result.category, default: 0] += 1
        }
    }
}
