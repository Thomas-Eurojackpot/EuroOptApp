//
//  PrizeClassCalculator.swift
//  EuroOpt
//
//  Alpha 6.5
//

import Foundation

struct PrizeClassCalculator {

    static func calculate(
        from results: [BacktestResult]
    ) -> [PrizeClassStatistics] {

        var counts: [String: Int] = [:]

        for result in results {

            for ticket in result.ticketResults {

                counts[ticket.prizeClass, default: 0] += 1

            }

        }

        return counts
            .map {

                PrizeClassStatistics(
                    prizeClass: $0.key,
                    count: $0.value
                )

            }
            .sorted {

                let lhs = $0.prizeClass.split(separator: "+")

                let rhs = $1.prizeClass.split(separator: "+")

                let lhsHits = Int(lhs[0]) ?? 0
                let lhsEuro = Int(lhs[1]) ?? 0

                let rhsHits = Int(rhs[0]) ?? 0
                let rhsEuro = Int(rhs[1]) ?? 0

                if lhsHits == rhsHits {

                    return lhsEuro > rhsEuro

                }

                return lhsHits > rhsHits

            }

    }

}
