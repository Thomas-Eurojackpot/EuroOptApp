//
//  WeightMutator.swift
//  EuroOpt
//
//  Alpha 7.1
//

import Foundation

struct WeightMutator {

    func mutate(
        goal: OptimizationGoal
    ) -> OptimizationGoal {

        var newGoal = goal

        // 2–4 Gewichte gleichzeitig verändern
        let mutations = Int.random(in: 2...4)

        for _ in 0..<mutations {

            switch Int.random(in: 0..<6) {

            case 0:
                newGoal.frequencyWeight += Double.random(in: -8...8)

            case 1:
                newGoal.pairWeight += Double.random(in: -8...8)

            case 2:
                newGoal.evenOddWeight += Double.random(in: -8...8)

            case 3:
                newGoal.highLowWeight += Double.random(in: -8...8)

            case 4:
                newGoal.sumWeight += Double.random(in: -8...8)

            default:
                newGoal.gapWeight += Double.random(in: -8...8)

            }

        }

        // Untergrenzen
        newGoal.frequencyWeight = max(0, newGoal.frequencyWeight)
        newGoal.pairWeight      = max(0, newGoal.pairWeight)
        newGoal.evenOddWeight   = max(0, newGoal.evenOddWeight)
        newGoal.highLowWeight   = max(0, newGoal.highLowWeight)
        newGoal.sumWeight       = max(0, newGoal.sumWeight)
        newGoal.gapWeight       = max(0, newGoal.gapWeight)

        // Auf 100 normieren
        let total =
            newGoal.frequencyWeight +
            newGoal.pairWeight +
            newGoal.evenOddWeight +
            newGoal.highLowWeight +
            newGoal.sumWeight +
            newGoal.gapWeight

        if total > 0 {

            let factor = 100.0 / total

            newGoal.frequencyWeight *= factor
            newGoal.pairWeight *= factor
            newGoal.evenOddWeight *= factor
            newGoal.highLowWeight *= factor
            newGoal.sumWeight *= factor
            newGoal.gapWeight *= factor

        }

        return newGoal

    }

}
