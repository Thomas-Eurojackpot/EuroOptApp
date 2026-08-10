//
//  WeightMutator.swift
//  EuroOpt
//
//  Alpha 7.3
//

import Foundation

struct WeightMutator {

    func mutate(
        goal: OptimizationGoal
    ) -> OptimizationGoal {

        var newGoal = goal

        // 2–5 Gewichte gleichzeitig verändern
        let mutationCount = Int.random(in: 2...5)

        for _ in 0..<mutationCount {

            switch Int.random(in: 0..<6) {

            case 0:
                newGoal.frequencyWeight += Double.random(in: -10...10)

            case 1:
                newGoal.pairWeight += Double.random(in: -10...10)

            case 2:
                newGoal.evenOddWeight += Double.random(in: -8...8)

            case 3:
                newGoal.highLowWeight += Double.random(in: -8...8)

            case 4:
                newGoal.sumWeight += Double.random(in: -8...8)

            default:
                newGoal.gapWeight += Double.random(in: -5...5)

            }

        }

        newGoal.frequencyWeight = max(0, newGoal.frequencyWeight)
        newGoal.pairWeight      = max(0, newGoal.pairWeight)
        newGoal.evenOddWeight   = max(0, newGoal.evenOddWeight)
        newGoal.highLowWeight   = max(0, newGoal.highLowWeight)
        newGoal.sumWeight       = max(0, newGoal.sumWeight)
        newGoal.gapWeight       = max(0, newGoal.gapWeight)

        let total =
            newGoal.frequencyWeight +
            newGoal.pairWeight +
            newGoal.evenOddWeight +
            newGoal.highLowWeight +
            newGoal.sumWeight +
            newGoal.gapWeight

        guard total > 0 else {
            return goal
        }

        let factor = 100.0 / total

        newGoal.frequencyWeight *= factor
        newGoal.pairWeight *= factor
        newGoal.evenOddWeight *= factor
        newGoal.highLowWeight *= factor
        newGoal.sumWeight *= factor
        newGoal.gapWeight *= factor

        return newGoal

    }

}
