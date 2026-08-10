//
//  WeightSweepEngine.swift
//  EuroOpt
//
//  Alpha 7.5 - automatic EQI weight sweep with holdout validation
//

import Foundation

final class WeightSweepEngine {

    private struct Profile {
        let id: Int
        let goal: OptimizationGoal
        let weights: [Double]
    }

    private struct Aggregate {
        var hits = 0
        var euroHits = 0
        var tickets = 0
    }

    // 32 deterministic profiles: enough exploration without turning one run
    // into an unnecessarily long optimization job.
    private let profileCount = 32
    private let candidateCountMinimum = 301

    func run(
        draws: [EuroJackpotDraw],
        recommendationCount: Int
    ) {

        guard draws.count > 140 else {
            print("❌ Weight-Sweep: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let totalTests = draws.count - 100
        let validationTests = totalTests / 2
        let holdoutStart = 100 + validationTests
        let profiles = makeProfiles()
        let generator = TicketGenerator()
        let candidateCount = max(AppSettings.backtestCandidateCount + 1, candidateCountMinimum)
        let scoreEngines = profiles.map { ScoreEngine(goal: $0.goal) }

        var validationTotals = Array(repeating: Aggregate(), count: profiles.count)

        print("")
        print("===================================")
        print("🧭 ALPHA 7.5 WEIGHT-SWEEP")
        print("===================================")
        print("Gesamte Ziehungen   : \(totalTests)")
        print("Validation          : \(validationTests)")
        print("Holdout             : \(totalTests - validationTests)")
        print("Profile             : \(profiles.count)")
        print("Kandidaten je Test  : \(candidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("")
        print("🔒 Holdout bleibt bis zur Gewichtswahl unangetastet.")
        print("")

        // Phase 1: select weights only on the first half of the rolling backtest.
        for index in 100..<holdoutStart {
            let trainingDraws = Array(draws.prefix(index))
            let targetDraw = draws[index]
            let candidates = generator.generate(
                count: candidateCount,
                draws: trainingDraws,
                goal: OptimizationGoal(),
                hillClimbingIterations: 0
            )

            for profileIndex in profiles.indices {
                let best = bestTickets(
                    candidates: candidates,
                    draws: trainingDraws,
                    scoreEngine: scoreEngines[profileIndex],
                    limit: recommendationCount
                )
                let hits = best.reduce(0) { $0 + Set($1.numbers).intersection(targetDraw.numbers).count }
                let euroHits = best.reduce(0) { $0 + Set($1.euroNumbers).intersection(targetDraw.euroNumbers).count }
                validationTotals[profileIndex].hits += hits
                validationTotals[profileIndex].euroHits += euroHits
                validationTotals[profileIndex].tickets += best.count
            }

            if (index - 99).isMultiple(of: 50) {
                print("... Validation \(index - 99) / \(validationTests)")
            }
        }

        let ranked = profiles.indices.sorted { lhs, rhs in
            let left = validationTotals[lhs]
            let right = validationTotals[rhs]
            let leftAverage = left.tickets > 0 ? Double(left.hits) / Double(left.tickets) : 0
            let rightAverage = right.tickets > 0 ? Double(right.hits) / Double(right.tickets) : 0
            return leftAverage > rightAverage
        }

        guard let winnerIndex = ranked.first else { return }
        let winner = profiles[winnerIndex]
        let winnerValidation = validationTotals[winnerIndex]
        let validationAverage = winnerValidation.tickets > 0
            ? Double(winnerValidation.hits) / Double(winnerValidation.tickets)
            : 0
        let validationEuroAverage = winnerValidation.tickets > 0
            ? Double(winnerValidation.euroHits) / Double(winnerValidation.tickets)
            : 0

        print("")
        print("-----------------------------------")
        print("TOP 10 VALIDATION")
        print("-----------------------------------")
        for (rank, profileIndex) in ranked.prefix(10).enumerated() {
            let total = validationTotals[profileIndex]
            let average = total.tickets > 0 ? Double(total.hits) / Double(total.tickets) : 0
            print(String(format: "%2d. P%02d  Haupt %.3f  Euro %.3f  %@",
                         rank + 1,
                         profiles[profileIndex].id,
                         average,
                         total.tickets > 0 ? Double(total.euroHits) / Double(total.tickets) : 0,
                         weightLabel(profiles[profileIndex])))
        }

        print("")
        print("🏆 GEWÄHLTES VALIDATION-PROFIL P\(String(format: "%02d", winner.id))")
        print(String(format: "Haupt %.3f | Euro %.3f", validationAverage, validationEuroAverage))
        print(weightLabel(winner))
        print("")
        print("🔒 Jetzt erst folgt der unabhängige Holdout-Test.")

        // Phase 2: freeze the selected profile and evaluate it only on unseen draws.
        let winnerScoreEngine = ScoreEngine(goal: winner.goal)
        var holdoutHits = 0
        var holdoutEuroHits = 0
        var holdoutTickets = 0

        for index in holdoutStart..<draws.count {
            let trainingDraws = Array(draws.prefix(index))
            let targetDraw = draws[index]
            let candidates = generator.generate(
                count: candidateCount,
                draws: trainingDraws,
                goal: OptimizationGoal(),
                hillClimbingIterations: 0
            )
            let best = bestTickets(
                candidates: candidates,
                draws: trainingDraws,
                scoreEngine: winnerScoreEngine,
                limit: recommendationCount
            )

            holdoutHits += best.reduce(0) { $0 + Set($1.numbers).intersection(targetDraw.numbers).count }
            holdoutEuroHits += best.reduce(0) { $0 + Set($1.euroNumbers).intersection(targetDraw.euroNumbers).count }
            holdoutTickets += best.count

            let current = index - holdoutStart + 1
            if current.isMultiple(of: 50) {
                print("... Holdout \(current) / \(totalTests - validationTests)")
            }
        }

        let holdoutAverage = holdoutTickets > 0 ? Double(holdoutHits) / Double(holdoutTickets) : 0
        let holdoutEuroAverage = holdoutTickets > 0 ? Double(holdoutEuroHits) / Double(holdoutTickets) : 0
        let randomMain = 0.50
        let randomEuro = 1.0 / 3.0

        print("")
        print("===================================")
        print("🧪 ALPHA 7.5 HOLDOUT-ERGEBNIS")
        print("===================================")
        print(String(format: "Gewichte            : %@", weightLabel(winner)))
        print(String(format: "Ø Haupttreffer      : %.3f", holdoutAverage))
        print(String(format: "Ø Eurotreffer       : %.3f", holdoutEuroAverage))
        print(String(format: "Zufall theoretisch  : %.3f / %.3f", randomMain, randomEuro))
        print(String(format: "Δ Haupt vs Zufall   : %+.3f", holdoutAverage - randomMain))
        print(String(format: "Δ Euro vs Zufall    : %+.3f", holdoutEuroAverage - randomEuro))
        print("")
        print("Interpretation: Die Gewichte wurden NICHT auf dem Holdout optimiert.")
        print("Nur wenn der Holdout ebenfalls positiv ist, ist das Profil interessant.")
        print("")
        print(String(format: "⏱ Weight-Sweep: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func bestTickets(
        candidates: [Ticket],
        draws: [EuroJackpotDraw],
        scoreEngine: ScoreEngine,
        limit: Int
    ) -> [Ticket] {

        guard !candidates.isEmpty else { return [] }
        let scored = candidates.map { ($0, scoreEngine.score(ticket: $0, draws: draws)) }
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

    private func commonNumbers(_ lhs: Ticket, _ rhs: Ticket) -> Int {
        var count = 0
        for number in lhs.numbers where rhs.numbers.contains(number) {
            count += 1
            if count >= 3 { return count }
        }
        return count
    }

    private func makeProfiles() -> [Profile] {
        var profiles: [Profile] = []

        // Fixed reference profiles make the sweep interpretable.
        let fixed: [[Double]] = [
            [100, 0, 0, 0, 0, 0],
            [0, 100, 0, 0, 0, 0],
            [0, 0, 100, 0, 0, 0],
            [0, 0, 0, 100, 0, 0],
            [0, 0, 0, 0, 100, 0],
            [0, 0, 0, 0, 0, 100],
            [30, 25, 15, 15, 15, 0]
        ]

        for weights in fixed {
            profiles.append(Profile(id: profiles.count + 1, goal: makeGoal(weights), weights: weights))
        }

        // Deterministic random sweep. Fixed seed means runs are reproducible.
        var state: UInt64 = 0xA7_5001_2026
        while profiles.count < profileCount {
            var raw: [Double] = []
            raw.reserveCapacity(6)
            var total = 0.0
            for _ in 0..<6 {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                let value = Double(Int(state % 100) + 1)
                raw.append(value)
                total += value
            }
            let weights = raw.map { $0 / total * 100.0 }
            profiles.append(Profile(id: profiles.count + 1, goal: makeGoal(weights), weights: weights))
        }

        return profiles
    }

    private func makeGoal(_ weights: [Double]) -> OptimizationGoal {
        OptimizationGoal(
            frequencyWeight: weights[0],
            pairWeight: weights[1],
            evenOddWeight: weights[2],
            highLowWeight: weights[3],
            sumWeight: weights[4],
            gapWeight: weights[5]
        )
    }

    private func weightLabel(_ profile: Profile) -> String {
        String(format: "F %.0f | P %.0f | G/U %.0f | H/N %.0f | S %.0f | A %.0f",
               profile.weights[0], profile.weights[1], profile.weights[2],
               profile.weights[3], profile.weights[4], profile.weights[5])
    }
}
