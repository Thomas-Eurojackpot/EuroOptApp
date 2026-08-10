//
//  ScoreComponent.swift
//  EuroOpt
//
//  Alpha 4.1
//

import Foundation

struct ScoreComponent: Identifiable {

    // MARK: - Properties

    let id = UUID()

    /// Anzeigename des Bewertungsmoduls
    let name: String

    /// Erreichte Punkte (0...100)
    let score: Double

    /// Gewichtung in Prozent
    let weight: Double

    // MARK: - Berechnete Eigenschaften

    /// Gewichteter Beitrag zum EQI
    var weightedScore: Double {

        score * weight / 100.0

    }

}
