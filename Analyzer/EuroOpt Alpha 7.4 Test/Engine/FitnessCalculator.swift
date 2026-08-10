//
//  FitnessCalculator.swift
//  EuroOpt
//
//  Alpha 7.1
//

import Foundation

struct FitnessCalculator {

    func fitness(
        from statistics: BacktestStatistics
    ) -> Double {

        var score = 0.0

        // Hauptziel
        score += statistics.averageHits * 10000

        // Zweitziel
        score += statistics.averageEuroHits * 3000

        // Beste Treffer
        score += Double(statistics.bestHits) * 1500
        score += Double(statistics.bestEuroHits) * 800

        // Gewinnklassen
        for prize in statistics.prizeClasses {

            switch prize.prizeClass {

            case "5+2":
                score += Double(prize.count) * 1_000_000

            case "5+1":
                score += Double(prize.count) * 250_000

            case "5+0":
                score += Double(prize.count) * 80_000

            case "4+2":
                score += Double(prize.count) * 15_000

            case "4+1":
                score += Double(prize.count) * 5_000

            case "4+0":
                score += Double(prize.count) * 1_500

            case "3+2":
                score += Double(prize.count) * 500

            case "3+1":
                score += Double(prize.count) * 100

            case "3+0":
                score += Double(prize.count) * 40

            case "2+2":
                score += Double(prize.count) * 25

            case "2+1":
                score += Double(prize.count) * 10

            case "1+2":
                score += Double(prize.count) * 5

            default:
                break

            }

        }

        return score

    }

}
