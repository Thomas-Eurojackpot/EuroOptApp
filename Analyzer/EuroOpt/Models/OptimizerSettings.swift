import Foundation

struct OptimizerSettings {

    // MARK: - Optimizer

    /// Anzahl der zufällig erzeugten Kandidaten
    var candidateCount: Int = 1000

    /// Anzahl der auszugebenden Empfehlungen
    var recommendationCount: Int = 8

    // MARK: - EQI-Gewichtung

    var frequencyWeight: Double = 30

    var pairWeight: Double = 25

    var evenOddWeight: Double = 15

    var highLowWeight: Double = 15

    var sumWeight: Double = 15

    var gapWeight: Double = 0

}
