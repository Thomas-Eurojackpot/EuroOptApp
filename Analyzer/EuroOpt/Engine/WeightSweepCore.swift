//
//  WeightSweepCore.swift
//  EuroOpt
//
//  Shared calculation core for Alpha 7.5 WeightSweepEngine and robustness analysis.
//  Keeps profile generation, ticket selection and scoring mechanics in one place.
//

import Foundation

struct WeightSweepProfile {
    let id: Int
    let goal: OptimizationGoal
    let weights: [Double]
}

struct WeightSweepAggregate {
    var hits = 0
    var euroHits = 0
    var tickets = 0
    var expectedEuroHits = 0.0

    var averageMain: Double {
        tickets > 0 ? Double(hits) / Double(tickets) : 0
    }

    var averageEuro: Double {
        tickets > 0 ? Double(euroHits) / Double(tickets) : 0
    }

    var averageExpectedEuro: Double {
        tickets > 0 ? expectedEuroHits / Double(tickets) : 0
    }

    var validationScore: Double {
        (averageMain - 0.50) + (averageEuro - averageExpectedEuro)
    }
}

struct WeightSweepCore {

    static let profileCount = 32
    static let candidateCountMinimum = 301
    static let warmup = 100

    static func makeProfiles() -> [WeightSweepProfile] {
        var profiles: [WeightSweepProfile] = []

        let singles: [[Double]] = [
            [100, 0, 0, 0, 0, 0],
            [0, 100, 0, 0, 0, 0],
            [0, 0, 100, 0, 0, 0],
            [0, 0, 0, 100, 0, 0],
            [0, 0, 0, 0, 100, 0],
            [0, 0, 0, 0, 0, 100]
        ]

        for weights in singles {
            profiles.append(makeProfile(id: profiles.count + 1, weights: weights))
        }

        for lhs in 0..<6 {
            for rhs in (lhs + 1)..<6 {
                var weights = Array(repeating: 0.0, count: 6)
                weights[lhs] = 50
                weights[rhs] = 50
                profiles.append(makeProfile(id: profiles.count + 1, weights: weights))
            }
        }

        for a in 0..<4 {
            for b in (a + 1)..<5 {
                for c in (b + 1)..<6 {
                    var weights = Array(repeating: 0.0, count: 6)
                    weights[a] = 34
                    weights[b] = 33
                    weights[c] = 33
                    profiles.append(makeProfile(id: profiles.count + 1, weights: weights))
                }
            }
        }

        let diversified = [20.0, 20.0, 15.0, 15.0, 15.0, 15.0]
        profiles.append(makeProfile(id: profiles.count + 1, weights: diversified))

        return Array(profiles.prefix(profileCount))
    }

    static func makeProfile(id: Int, weights: [Double]) -> WeightSweepProfile {
        WeightSweepProfile(id: id, goal: makeGoal(weights), weights: weights)
    }

    static func makeGoal(_ weights: [Double]) -> OptimizationGoal {
        OptimizationGoal(
            frequencyWeight: weights[0],
            pairWeight: weights[1],
            evenOddWeight: weights[2],
            highLowWeight: weights[3],
            sumWeight: weights[4],
            gapWeight: weights[5]
        )
    }

    static func candidateCount() -> Int {
        max(AppSettings.backtestCandidateCount + 1, candidateCountMinimum)
    }

    static func bestTickets(candidates: [Ticket], scoreEngine: ScoreEngine, limit: Int) -> [Ticket] {
        guard !candidates.isEmpty else { return [] }

        let scored = candidates
            .map { ($0, scoreEngine.score(ticket: $0)) }
            .sorted { $0.1 > $1.1 }

        var result: [Ticket] = []
        result.reserveCapacity(limit)

        for candidate in scored {
            var different = true
            for existing in result {
                if commonNumbers(existing, candidate.0) >= 3 {
                    different = false
                    break
                }
            }

            if different {
                result.append(candidate.0)
                if result.count == limit { break }
            }
        }

        return result
    }

    static func commonNumbers(_ lhs: Ticket, _ rhs: Ticket) -> Int {
        var count = 0
        for number in lhs.numbers where rhs.numbers.contains(number) {
            count += 1
            if count >= 3 { return count }
        }
        return count
    }

    static func expectedEuroHits(for date: Date, ticketCount: Int) -> Double {
        guard ticketCount > 0 else { return 0 }
        let expectedPerTicket = date < euroFormatCutoverDate() ? 0.400 : (1.0 / 3.0)
        return expectedPerTicket * Double(ticketCount)
    }

    static func euroFormatCutoverDate() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: 2022, month: 3, day: 25))!
    }

    static func hypergeometricProbability(successPopulation: Int,
                                          failurePopulation: Int,
                                          draws: Int,
                                          successes: Int) -> Double {
        guard successes >= 0,
              successes <= draws,
              successes <= successPopulation,
              draws - successes <= failurePopulation else { return 0 }

        return combination(successPopulation, successes)
            * combination(failurePopulation, draws - successes)
            / combination(successPopulation + failurePopulation, draws)
    }

    static func combination(_ n: Int, _ k: Int) -> Double {
        guard k >= 0, k <= n else { return 0 }
        if k == 0 || k == n { return 1 }

        let m = min(k, n - k)
        var result = 1.0
        for i in 1...m {
            result *= Double(n - m + i) / Double(i)
        }
        return result
    }
}
