//
//  FitnessCalculator.swift
//  EuroOpt
//
//  Alpha 7.3
//

import Foundation

struct FitnessCalculator {

    func fitness(
        from statistics: BacktestStatistics
    ) -> Double {

        var score = 0.0

        // Hauptziel
        score += statistics.averageHits * 20_000

        // Eurozahlen
        score += statistics.averageEuroHits * 8_000

        // Beste Ergebnisse
        score += Double(statistics.bestHits) * 3_000
        score += Double(statistics.bestEuroHits) * 1_500

        // Gewinnklassen
        for prize in statistics.prizeClasses {

            switch prize.prizeClass {

            case "5+2":
                score += Double(prize.count) * 2_000_000

            case "5+1":
                score += Double(prize.count) * 500_000

            case "5+0":
                score += Double(prize.count) * 150_000

            case "4+2":
                score += Double(prize.count) * 25_000

            case "4+1":
                score += Double(prize.count) * 8_000

            case "4+0":
                score += Double(prize.count) * 2_500

            case "3+2":
                score += Double(prize.count) * 1_000

            case "3+1":
                score += Double(prize.count) * 300

            case "3+0":
                score += Double(prize.count) * 100

            case "2+2":
                score += Double(prize.count) * 50

            case "2+1":
                score += Double(prize.count) * 20

            case "1+2":
                score += Double(prize.count) * 10

            default:
                break
            }
        }

        return score

    }

}
