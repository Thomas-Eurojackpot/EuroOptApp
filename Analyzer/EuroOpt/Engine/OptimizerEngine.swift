//
//  OptimizerEngine.swift
//  EuroOpt
//
//  Alpha 7.0
//

import Foundation

final class OptimizerEngine {

    // MARK: - Properties

    private let scoreEngine: ScoreEngine

    // MARK: - Initializer

    init(
        goal: OptimizationGoal = OptimizationGoal()
    ) {

        self.scoreEngine = ScoreEngine(
            goal: goal
        )

    }

    // MARK: - Public

    func updateGoal(
        _ goal: OptimizationGoal
    ) {

        scoreEngine.updateGoal(goal)

    }

    func bestTickets(
        from candidates: [Ticket],
        draws: [EuroJackpotDraw],
        goal: OptimizationGoal? = nil,
        limit: Int = 8
    ) -> [(ticket: Ticket, score: Double)] {

        if let goal {

            scoreEngine.updateGoal(goal)

        }

        print("🎯 Optimizer bewertet \(candidates.count) Tickets")

        guard !candidates.isEmpty else {
            return []
        }

        let keepCount = max(limit * 4, 32)

        var best: [(ticket: Ticket, score: Double)] = []
        best.reserveCapacity(keepCount)

        for ticket in candidates {

            let score = scoreEngine.score(
                ticket: ticket,
                draws: draws
            )

            if best.count < keepCount {

                best.append((ticket, score))

                if best.count == keepCount {
                    best.sort { $0.score > $1.score }
                }

                continue
            }

            guard score > best[keepCount - 1].score else {
                continue
            }

            var low = 0
            var high = keepCount - 1

            while low < high {

                let mid = (low + high) / 2

                if score > best[mid].score {
                    high = mid
                } else {
                    low = mid + 1
                }

            }

            best.insert((ticket, score), at: low)
            best.removeLast()

        }

        if best.count < keepCount {
            best.sort { $0.score > $1.score }
        }

        var result: [(ticket: Ticket, score: Double)] = []
        result.reserveCapacity(limit)

        for candidate in best {

            var different = true

            for existing in result {

                if commonNumbers(
                    existing.ticket,
                    candidate.ticket
                ) >= 3 {

                    different = false
                    break

                }

            }

            if different {

                result.append(candidate)

                if result.count == limit {
                    break
                }

            }

        }

        print("✅ Optimizer fertig (\(result.count) Tickets)")

        return result

    }

    // MARK: - Private

    @inline(__always)
    private func commonNumbers(
        _ lhs: Ticket,
        _ rhs: Ticket
    ) -> Int {

        var count = 0

        for number in lhs.numbers {

            if rhs.numbers.contains(number) {

                count += 1

                if count >= 3 {
                    return count
                }

            }

        }

        return count

    }

}
