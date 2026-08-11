import Foundation

struct LearningResult {
    let goal: OptimizationGoal
    let testedDraws: Int
    let improvedSteps: Int
    let averageHits: Double
    let averageEuroHits: Double
    let duration: Double
}

/// Walk-forward learner for the EQI weights.
///
/// Important: the target draw is NEVER used to choose its own recommendation.
/// The learner first evaluates the current profile, then reveals the target,
/// measures the individual component models, and only then updates the profile
/// for the NEXT draw.
final class LearningEngine {

    private enum Component: CaseIterable {
        case frequency
        case pair
        case evenOdd
        case highLow
        case sum
        case gap

        var name: String {
            switch self {
            case .frequency: return "Frequenz"
            case .pair: return "Paare"
            case .evenOdd: return "Gerade/Ungerade"
            case .highLow: return "Hoch/Niedrig"
            case .sum: return "Summe"
            case .gap: return "Abstände"
            }
        }
    }

    private var weights: [Component: Double]
    private let learningRate = 1.5
    private let minimumWeight = 0.03

    init(startingGoal: OptimizationGoal = OptimizationGoalStore.shared.currentGoal) {
        weights = [
            .frequency: max(startingGoal.frequencyWeight, minimumWeight),
            .pair: max(startingGoal.pairWeight, minimumWeight),
            .evenOdd: max(startingGoal.evenOddWeight, minimumWeight),
            .highLow: max(startingGoal.highLowWeight, minimumWeight),
            .sum: max(startingGoal.sumWeight, minimumWeight),
            .gap: max(startingGoal.gapWeight, minimumWeight)
        ]
        normalize()
    }

    func learn(
        draws: [EuroJackpotDraw],
        recommendationCount: Int,
        candidateCount: Int = 501
    ) -> LearningResult {

        guard draws.count > 100 else {
            return LearningResult(
                goal: OptimizationGoalStore.shared.currentGoal,
                testedDraws: 0,
                improvedSteps: 0,
                averageHits: 0,
                averageEuroHits: 0,
                duration: 0
            )
        }

        let start = Date()
        let actualCandidateCount = max(100, candidateCount)
        let totalTests = draws.count - 100
        let generator = TicketGenerator()

        var totalHits = 0
        var totalEuroHits = 0
        var totalTickets = 0
        var improvedSteps = 0

        print("")
        print("===================================")
        print("🧠 EUROOPT GEWICHTE LERNEN")
        print("===================================")
        print("Walk-Forward : JA")
        print("Getestete Ziehungen : \(totalTests)")
        print("Kandidaten je Test  : \(actualCandidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("Regel                : Update erst NACH Ziehung")
        print("===================================")

        for index in 100..<draws.count {
            let trainingDraws = Array(draws.prefix(index))
            let targetDraw = draws[index]

            // Identical candidate pool for every component. The pool itself
            // does not depend on the learned weights.
            let candidates = generator.generate(
                count: actualCandidateCount,
                draws: trainingDraws,
                goal: OptimizationGoal(),
                hillClimbingIterations: 0
            )

            // Recommendation for this target is selected BEFORE targetDraw is
            // evaluated. This is the actual walk-forward decision.
            let adaptiveBest = OptimizerEngine().bestTickets(
                from: candidates,
                draws: trainingDraws,
                goal: goal,
                limit: recommendationCount
            )

            var adaptiveHits = 0
            var adaptiveEuroHits = 0

            for candidate in adaptiveBest {
                adaptiveHits += Set(candidate.ticket.numbers)
                    .intersection(targetDraw.numbers).count
                adaptiveEuroHits += Set(candidate.ticket.euroNumbers)
                    .intersection(targetDraw.euroNumbers).count
            }

            totalHits += adaptiveHits
            totalEuroHits += adaptiveEuroHits
            totalTickets += adaptiveBest.count

            // Only after the target is known do we measure the experts and
            // update the weights for the next chronological step.
            var observed: [Component: Double] = [:]

            for component in Component.allCases {
                let optimizer = OptimizerEngine()
                let best = optimizer.bestTickets(
                    from: candidates,
                    draws: trainingDraws,
                    goal: goal(for: component),
                    limit: recommendationCount
                )

                guard !best.isEmpty else {
                    observed[component] = 0.5
                    continue
                }

                var hits = 0
                for candidate in best {
                    hits += Set(candidate.ticket.numbers)
                        .intersection(targetDraw.numbers).count
                }

                observed[component] = Double(hits) / Double(best.count)
            }

            let before = goal
            update(using: observed)

            if goalDistance(goal, before) > 0.001 {
                improvedSteps += 1
            }

            if (index - 99).isMultiple(of: 100) || index == draws.count - 1 {
                let current = index - 99
                let avgHits = totalTickets > 0
                    ? Double(totalHits) / Double(totalTickets)
                    : 0
                let avgEuro = totalTickets > 0
                    ? Double(totalEuroHits) / Double(totalTickets)
                    : 0

                print(String(
                    format: "🧠 Lernen %3d/%3d | Ø %.3f / %.3f | Profil %@",
                    current,
                    totalTests,
                    avgHits,
                    avgEuro,
                    profileText()
                ))
            }
        }

        let finalGoal = goal
        OptimizationGoalStore.shared.update(finalGoal)

        let averageHits = totalTickets > 0
            ? Double(totalHits) / Double(totalTickets)
            : 0
        let averageEuroHits = totalTickets > 0
            ? Double(totalEuroHits) / Double(totalTickets)
            : 0
        let duration = Date().timeIntervalSince(start)

        print("")
        print("===================================")
        print("🧠 GELERNTES PROFIL")
        print("===================================")
        print(String(format: "Frequenz       : %5.1f %%", finalGoal.frequencyWeight))
        print(String(format: "Paare          : %5.1f %%", finalGoal.pairWeight))
        print(String(format: "Gerade/Ungerade: %5.1f %%", finalGoal.evenOddWeight))
        print(String(format: "Hoch/Niedrig   : %5.1f %%", finalGoal.highLowWeight))
        print(String(format: "Summe           : %5.1f %%", finalGoal.sumWeight))
        print(String(format: "Abstände        : %5.1f %%", finalGoal.gapWeight))
        print("")
        print(String(format: "Ø Haupttreffer : %.3f", averageHits))
        print(String(format: "Ø Eurotreffer  : %.3f", averageEuroHits))
        print("Verbesserte Schritte: \(improvedSteps)")
        print(String(format: "⏱ Lernen: %.2f Sekunden", duration))
        print("===================================")

        return LearningResult(
            goal: finalGoal,
            testedDraws: totalTests,
            improvedSteps: improvedSteps,
            averageHits: averageHits,
            averageEuroHits: averageEuroHits,
            duration: duration
        )
    }

    private var goal: OptimizationGoal {
        OptimizationGoal(
            frequencyWeight: normalized(.frequency),
            pairWeight: normalized(.pair),
            evenOddWeight: normalized(.evenOdd),
            highLowWeight: normalized(.highLow),
            sumWeight: normalized(.sum),
            gapWeight: normalized(.gap)
        )
    }

    private func goal(for component: Component) -> OptimizationGoal {
        switch component {
        case .frequency:
            return OptimizationGoal(frequencyWeight: 100, pairWeight: 0, evenOddWeight: 0, highLowWeight: 0, sumWeight: 0, gapWeight: 0)
        case .pair:
            return OptimizationGoal(frequencyWeight: 0, pairWeight: 100, evenOddWeight: 0, highLowWeight: 0, sumWeight: 0, gapWeight: 0)
        case .evenOdd:
            return OptimizationGoal(frequencyWeight: 0, pairWeight: 0, evenOddWeight: 100, highLowWeight: 0, sumWeight: 0, gapWeight: 0)
        case .highLow:
            return OptimizationGoal(frequencyWeight: 0, pairWeight: 0, evenOddWeight: 0, highLowWeight: 100, sumWeight: 0, gapWeight: 0)
        case .sum:
            return OptimizationGoal(frequencyWeight: 0, pairWeight: 0, evenOddWeight: 0, highLowWeight: 0, sumWeight: 100, gapWeight: 0)
        case .gap:
            return OptimizationGoal(frequencyWeight: 0, pairWeight: 0, evenOddWeight: 0, highLowWeight: 0, sumWeight: 0, gapWeight: 100)
        }
    }

    private func update(using observed: [Component: Double]) {
        for component in Component.allCases {
            let value = observed[component] ?? 0.5
            let delta = max(-0.5, min(0.5, value - 0.5))
            let old = weights[component] ?? (1.0 / Double(Component.allCases.count))
            weights[component] = old * exp(learningRate * delta)
        }
        normalize()
    }

    private func normalized(_ component: Component) -> Double {
        let total = weights.values.reduce(0, +)
        guard total > 0 else { return 1.0 / Double(Component.allCases.count) }
        return (weights[component] ?? 0) / total * 100.0
    }

    private func normalize() {
        for component in Component.allCases {
            weights[component] = max(weights[component] ?? 0, minimumWeight)
        }

        let total = weights.values.reduce(0, +)
        guard total > 0 else { return }

        for component in Component.allCases {
            weights[component] = (weights[component] ?? 0) / total
        }
    }

    private func goalDistance(_ lhs: OptimizationGoal, _ rhs: OptimizationGoal) -> Double {
        abs(lhs.frequencyWeight - rhs.frequencyWeight)
            + abs(lhs.pairWeight - rhs.pairWeight)
            + abs(lhs.evenOddWeight - rhs.evenOddWeight)
            + abs(lhs.highLowWeight - rhs.highLowWeight)
            + abs(lhs.sumWeight - rhs.sumWeight)
            + abs(lhs.gapWeight - rhs.gapWeight)
    }

    private func profileText() -> String {
        String(format: "F%.0f P%.0f G/U%.0f H/N%.0f S%.0f A%.0f", normalized(.frequency), normalized(.pair), normalized(.evenOdd), normalized(.highLow), normalized(.sum), normalized(.gap))
    }
}
