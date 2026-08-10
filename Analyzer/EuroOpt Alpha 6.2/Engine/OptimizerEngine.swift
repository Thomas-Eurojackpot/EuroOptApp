//
//  OptimizerEngine.swift
//  EuroOpt
//
//  Alpha 6.1
//

import Foundation

final class OptimizerEngine {

    private let scoreEngine = ScoreEngine()

    func bestTickets(
        from candidates: [Ticket],
        draws: [EuroJackpotDraw],
        limit: Int = 8
    ) -> [(ticket: Ticket, score: Double)] {

        print("🎯 Optimizer bewertet \(candidates.count) Tickets")

        var scoredTickets: [(ticket: Ticket, score: Double)] = []

        scoredTickets.reserveCapacity(candidates.count)

        for ticket in candidates {

            let score = scoreEngine.score(
                ticket: ticket,
                draws: draws
            )

            scoredTickets.append(
                (
                    ticket: ticket,
                    score: score
                )
            )

        }

        scoredTickets.sort {
            $0.score > $1.score
        }

        var result: [(ticket: Ticket, score: Double)] = []

        result.reserveCapacity(limit)

        for candidate in scoredTickets {

            let isDifferent = result.allSatisfy {

                commonNumbers(
                    $0.ticket,
                    candidate.ticket
                ) < 3

            }

            if isDifferent {

                result.append(candidate)

            }

            if result.count == limit {

                break

            }

        }

        print("✅ Optimizer fertig")

        return result

    }

    private func commonNumbers(
        _ lhs: Ticket,
        _ rhs: Ticket
    ) -> Int {

        Set(lhs.numbers)
            .intersection(rhs.numbers)
            .count

    }

}
