//
//  BeamSearchEngine.swift
//  EuroOpt
//
//  Alpha 7.5
//

import Foundation

final class BeamSearchEngine {

    private let scoreEngine = ScoreEngine()
    private let mutator = SmartMutator()

    func optimize(
        ticket: Ticket,
        draws: [EuroJackpotDraw],
        width: Int = 6,
        depth: Int = 8
    ) -> Ticket {

        var beam: [(ticket: Ticket, score: Double)] = []
        beam.reserveCapacity(width * (depth + 1))

        var visited = Set<Ticket>()

        let startScore = scoreEngine.score(
            ticket: ticket,
            draws: draws
        )

        beam.append((ticket, startScore))
        visited.insert(ticket)

        for _ in 0..<depth {

            var next = beam

            for current in beam {

                for _ in 0..<width {

                    guard let candidate = mutator.mutate(
                        ticket: current.ticket
                    ) else {
                        continue
                    }

                    // Bereits bewertete Tickets überspringen
                    guard visited.insert(candidate).inserted else {
                        continue
                    }

                    let score = scoreEngine.score(
                        ticket: candidate,
                        draws: draws
                    )

                    next.append((candidate, score))
                }
            }

            next.sort { $0.score > $1.score }

            if next.count > width {
                next.removeSubrange(width...)
            }

            beam = next
        }

        return beam.first?.ticket ?? ticket
    }
}
