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
        print("Auswertung          : kombinierter Haupt-/Euro-Überschuss")
        print("")
        print("🔒 Holdout bleibt bis zur Gewichtswahl unangetastet.")
        print("")

        for index in 100..<holdoutStart {
            let trainingDraws = Array(draws.prefix(index))
            let targetDraw = draws[index]
            let candidates = generator.generate(
                count: candidateCount,
                draws: trainingDraws,
                goal: OptimizationGoal(),
                hillClimbingIterations: 0
            )

            let cache = ScoreCache(draws: trainingDraws)
            let scoreEngines = profiles.map { ScoreEngine(cache: cache, goal: $0.goal) }

            for profileIndex in profiles.indices {
                let best = bestTickets(
                    candidates: candidates,
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
            validationScore(validationTotals[lhs]) > validationScore(validationTotals[rhs])
        }

        guard let winnerIndex = ranked.first else { return }
        let winner = profiles[winnerIndex]
        let winnerValidation = validationTotals[winnerIndex]
        let validationAverage = averageMain(winnerValidation)
        let validationEuroAverage = averageEuro(winnerValidation)

        print("")
        print("-----------------------------------")
        print("TOP 10 VALIDATION – KOMBINATIONEN")
        print("-----------------------------------")
        for (rank, profileIndex) in ranked.prefix(10).enumerated() {
            let total = validationTotals[profileIndex]
            print(String(format: "%2d. P%02d  Haupt %.3f  Euro %.3f  Score %+.3f  %@",
                         rank + 1,
                         profiles[profileIndex].id,
                         averageMain(total),
                         averageEuro(total),
                         validationScore(total),
                         weightLabel(profiles[profileIndex])))
        }

        print("")
        print("🏆 GEWÄHLTES VALIDATION-PROFIL P\(String(format: "%02d", winner.id))")
        print(String(format: "Haupt %.3f | Euro %.3f | kombinierter Überschuss %+.3f",
                     validationAverage,
                     validationEuroAverage,
                     validationScore(winnerValidation)))
        print(weightLabel(winner))
        print("")
        print("🔒 Jetzt erst folgt der unabhängige Holdout-Test.")

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
            let cache = ScoreCache(draws: trainingDraws)
            let winnerScoreEngine = ScoreEngine(cache: cache, goal: winner.goal)
            let best = bestTickets(
                candidates: candidates,
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
        print(String(format: "Kombinierter Δ      : %+.3f", (holdoutAverage - randomMain) + (holdoutEuroAverage - randomEuro)))
        print("")
        print("Interpretation: Das Profil wurde ausschließlich auf der Validation-Hälfte gewählt.")
        print("Der Holdout wurde weder zur Gewichtswahl noch zur Kombinationsermittlung verwendet.")
        print("")
        print(String(format: "⏱ Weight-Sweep: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    // Pre-registered confirmation of the already selected G/U-only profile.
    // This does not select or tune weights. It is a fresh calculation on the
    // latest 100 draws, but those draws were already part of the previous
    // holdout, so this is a confirmation slice, not a statistically independent
    // second experiment. A truly independent experiment requires new draws.
    func runGUConfirmation(
        draws: [EuroJackpotDraw],
        recommendationCount: Int,
        windowSize: Int = 100
    ) {
        guard draws.count > windowSize + 100 else {
            print("❌ G/U-Bestätigung: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let firstIndex = max(100, draws.count - windowSize)
        let generator = TicketGenerator()
        let candidateCount = max(AppSettings.backtestCandidateCount + 1, candidateCountMinimum)
        let goal = makeGoal([0, 0, 100, 0, 0, 0])
        var hits = 0
        var euroHits = 0
        var tickets = 0

        print("")
        print("===================================")
        print("🧪 G/U-BESTÄTIGUNGS-TEST")
        print("===================================")
        print("Profil              : F 0 | P 0 | G/U 100 | H/N 0 | S 0 | A 0")
        print("Fenster             : letzte \(draws.count - firstIndex) Ziehungen")
        print("Gewichte fest       : JA — keine Optimierung")
        print("Kandidaten je Test  : \(candidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("⚠️ Dieses Fenster war Teil des bisherigen Holdouts.")
        print("⚠️ Daher keine statistisch unabhängige Wiederholung.")
        print("")

        for index in firstIndex..<draws.count {
            let trainingDraws = Array(draws.prefix(index))
            let targetDraw = draws[index]
            let candidates = generator.generate(
                count: candidateCount,
                draws: trainingDraws,
                goal: OptimizationGoal(),
                hillClimbingIterations: 0
            )
            let cache = ScoreCache(draws: trainingDraws)
            let scoreEngine = ScoreEngine(cache: cache, goal: goal)
            let best = bestTickets(
                candidates: candidates,
                scoreEngine: scoreEngine,
                limit: recommendationCount
            )

            hits += best.reduce(0) { $0 + Set($1.numbers).intersection(targetDraw.numbers).count }
            euroHits += best.reduce(0) { $0 + Set($1.euroNumbers).intersection(targetDraw.euroNumbers).count }
            tickets += best.count

            let current = index - firstIndex + 1
            if current.isMultiple(of: 25) {
                print("... Bestätigung \(current) / \(draws.count - firstIndex)")
            }
        }

        let average = tickets > 0 ? Double(hits) / Double(tickets) : 0
        let euroAverage = tickets > 0 ? Double(euroHits) / Double(tickets) : 0
        let randomMain = 0.50
        let randomEuro = 1.0 / 3.0

        print("")
        print("===================================")
        print("🧪 G/U-BESTÄTIGUNGS-ERGEBNIS")
        print("===================================")
        print("Gewichte            : F 0 | P 0 | G/U 100 | H/N 0 | S 0 | A 0")
        print(String(format: "Ø Haupttreffer      : %.3f", average))
        print(String(format: "Ø Eurotreffer       : %.3f", euroAverage))
        print(String(format: "Zufall theoretisch  : %.3f / %.3f", randomMain, randomEuro))
        print(String(format: "Δ Haupt vs Zufall   : %+.3f", average - randomMain))
        print(String(format: "Δ Euro vs Zufall    : %+.3f", euroAverage - randomEuro))
        print("Profil wurde vorher festgelegt: JA")
        print("Gewichte wurden im Test verändert: NEIN")
        print("Hinweis: Für echte Unabhängigkeit benötigen wir neue Ziehungen nach dem bisherigen Datenbestand.")
        print("")
        print(String(format: "⏱ G/U-Bestätigung: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func bestTickets(
        candidates: [Ticket],
        scoreEngine: ScoreEngine,
        limit: Int
    ) -> [Ticket] {

        guard !candidates.isEmpty else { return [] }
        let scored = candidates.map { ($0, scoreEngine.score(ticket: $0)) }
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

    private func averageMain(_ aggregate: Aggregate) -> Double {
        aggregate.tickets > 0 ? Double(aggregate.hits) / Double(aggregate.tickets) : 0
    }

    private func averageEuro(_ aggregate: Aggregate) -> Double {
        aggregate.tickets > 0 ? Double(aggregate.euroHits) / Double(aggregate.tickets) : 0
    }

    private func validationScore(_ aggregate: Aggregate) -> Double {
        let mainDelta = averageMain(aggregate) - 0.50
        let euroDelta = averageEuro(aggregate) - (1.0 / 3.0)
        return mainDelta + euroDelta
    }

    private func makeProfiles() -> [Profile] {
        var profiles: [Profile] = []

        // 6 single-factor profiles.
        let singles: [[Double]] = [
            [100, 0, 0, 0, 0, 0],
            [0, 100, 0, 0, 0, 0],
            [0, 0, 100, 0, 0, 0],
            [0, 0, 0, 100, 0, 0],
            [0, 0, 0, 0, 100, 0],
            [0, 0, 0, 0, 0, 100]
        ]

        for weights in singles {
            profiles.append(Profile(id: profiles.count + 1, goal: makeGoal(weights), weights: weights))
        }

        // 15 pairwise combinations at 50/50.
        for lhs in 0..<6 {
            for rhs in (lhs + 1)..<6 {
                var weights = Array(repeating: 0.0, count: 6)
                weights[lhs] = 50
                weights[rhs] = 50
                profiles.append(Profile(id: profiles.count + 1, goal: makeGoal(weights), weights: weights))
            }
        }

        // 10 three-factor combinations at 34/33/33.
        for a in 0..<4 {
            for b in (a + 1)..<5 {
                for c in (b + 1)..<6 {
                    var weights = Array(repeating: 0.0, count: 6)
                    weights[a] = 34
                    weights[b] = 33
                    weights[c] = 33
                    profiles.append(Profile(id: profiles.count + 1, goal: makeGoal(weights), weights: weights))
                }
            }
        }

        // One broad diversified baseline.
        let diversified = [20.0, 20.0, 15.0, 15.0, 15.0, 15.0]
        profiles.append(Profile(id: profiles.count + 1, goal: makeGoal(diversified), weights: diversified))

        return Array(profiles.prefix(profileCount))
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
