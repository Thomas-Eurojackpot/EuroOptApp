//
//  WeightFitness.swift
//  EuroOpt
//
//  Alpha 7.0
//

import Foundation

struct WeightFitness: Comparable {

    let goal: OptimizationGoal
    let fitness: Double

    // MARK: - Equatable

    static func == (
        lhs: WeightFitness,
        rhs: WeightFitness
    ) -> Bool {

        lhs.fitness == rhs.fitness

    }

    // MARK: - Comparable

    static func < (
        lhs: WeightFitness,
        rhs: WeightFitness
    ) -> Bool {

        lhs.fitness < rhs.fitness

    }

}
