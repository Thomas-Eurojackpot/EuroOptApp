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

    // Identical reference and synodic period as MoonPhaseEngine.
    // J2000 reference: Julian Day 2451550.09765.
    private let referenceNewMoon = 2451550.09765
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
        let nearestDate = Date(
            timeIntervalSince1970: (nearestJulianDay - 2440587.5) * 86400.0
        )

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

    // Pure historical analysis only.
    // No candidate generation, no weights, no Alpha 7.5 interaction.
    func runTest(draws: [EuroJackpotDraw]) {
        let start = Date()
        let results = analyze(draws: draws)

        guard !results.isEmpty else {
            print("❌ Neumond-Analyse: keine Ziehungen vorhanden")
            return
        }

        print("")
        print("===================================")
        print("🌑 NEUMOND – REINER ANALYSETEST")
        print("===================================")
        print("Ziehungen            : \(results.count)")
        print("Berechnung           : identisch zu MoonPhaseEngine")
        print("Alpha 7.5            : nicht verwendet")
        print("Gewichte / EQI       : nicht verwendet")
        print("Tippgenerierung      : nicht verwendet")
        print("")
        print("Kategorie             Anzahl     Anteil")

        for category in Category.allCases {
            let count = results.filter { $0.category == category }.count
            let share = Double(count) / Double(results.count) * 100.0
            print(String(format: "%-20s %6d     %6.2f %%", category.rawValue, count, share))
        }

        let exact = results.filter { $0.category == .exactDay }
        let within1 = results.filter { $0.category == .plusMinus1 }
        let within2 = results.filter { $0.category == .plusMinus2 }
        let within3 = results.filter { $0.category == .plusMinus3 }
        let farther = results.filter { $0.category == .farther }

        print("")
        print("Neumond-Tag         : \(exact.count)")
        print("±1 Tag              : \(within1.count)")
        print("±2 Tage             : \(within2.count)")
        print("±3 Tage             : \(within3.count)")
        print(">3 Tage             : \(farther.count)")

        print("")
        print("Interpretation:")
        print("- Dies ist ausschließlich eine historische Neumond-Klassifizierung.")
        print("- Es wird kein Profil gewählt und kein Tipp erzeugt.")
        print("- Alpha 7.5 und MoonPhaseEngine bleiben unangetastet.")
        print("- Die Neumond-Datumsberechnung verwendet exakt dieselbe Referenz und denselben synodischen Monat wie MoonPhaseEngine.")
        print(String(format: "# ⏱ Neumond-Analyse: %.2f Sekunden", Date().timeIntervalSince(start)))
    }
}
