//
//  BacktestStatistics.swift
//  EuroOpt
//
//  Alpha 6.5
//

import Foundation

struct BacktestStatistics {

    let totalTests: Int

    let averageHits: Double
    let averageEuroHits: Double
    let averageEQI: Double

    let bestHits: Int
    let bestEuroHits: Int

    // MARK: - Haupttreffer

    let hit0: Int
    let hit1: Int
    let hit2: Int
    let hit3: Int
    let hit4: Int
    let hit5: Int

    // MARK: - Eurotreffer

    let euroHit0: Int
    let euroHit1: Int
    let euroHit2: Int

    static func calculate(
        from results: [BacktestResult]
    ) -> BacktestStatistics {

        guard !results.isEmpty else {

            return BacktestStatistics(

                totalTests: 0,

                averageHits: 0,
                averageEuroHits: 0,
                averageEQI: 0,

                bestHits: 0,
                bestEuroHits: 0,

                hit0: 0,
                hit1: 0,
                hit2: 0,
                hit3: 0,
                hit4: 0,
                hit5: 0,

                euroHit0: 0,
                euroHit1: 0,
                euroHit2: 0

            )

        }

        let totalHits =
            results.reduce(0.0) { $0 + $1.averageHits }

        let totalEuroHits =
            results.reduce(0.0) { $0 + $1.averageEuroHits }

        let totalEQI =
            results.reduce(0.0) { $0 + $1.averageEQI }

        let bestHits =
            results.map(\.bestHits).max() ?? 0

        let bestEuroHits =
            results.map(\.bestEuroHits).max() ?? 0

        var hit0 = 0
        var hit1 = 0
        var hit2 = 0
        var hit3 = 0
        var hit4 = 0
        var hit5 = 0

        var euroHit0 = 0
        var euroHit1 = 0
        var euroHit2 = 0

        for result in results {

            for ticket in result.ticketResults {

                switch ticket.hits {

                case 0:
                    hit0 += 1

                case 1:
                    hit1 += 1

                case 2:
                    hit2 += 1

                case 3:
                    hit3 += 1

                case 4:
                    hit4 += 1

                default:
                    hit5 += 1

                }

                switch ticket.euroHits {

                case 0:
                    euroHit0 += 1

                case 1:
                    euroHit1 += 1

                default:
                    euroHit2 += 1

                }

            }

        }

        return BacktestStatistics(

            totalTests: results.count,

            averageHits:
                totalHits / Double(results.count),

            averageEuroHits:
                totalEuroHits / Double(results.count),

            averageEQI:
                totalEQI / Double(results.count),

            bestHits: bestHits,

            bestEuroHits: bestEuroHits,

            hit0: hit0,
            hit1: hit1,
            hit2: hit2,
            hit3: hit3,
            hit4: hit4,
            hit5: hit5,

            euroHit0: euroHit0,
            euroHit1: euroHit1,
            euroHit2: euroHit2

        )

    }

}
