//
//  BacktestSession.swift
//  EuroOpt
//
//  Alpha 7.0
//

import Foundation

final class BacktestSession {

    // MARK: - Properties

    let generator = TicketGenerator()

    let optimizer: OptimizerEngine

    private(set) var trainingDraws: [EuroJackpotDraw]

    let context: AnalysisContext

    // MARK: - Initialisierung

    init(
        trainingDraws: [EuroJackpotDraw],
        goal: OptimizationGoal = OptimizationGoal()
    ) {

        self.trainingDraws = trainingDraws

        self.optimizer = OptimizerEngine(
            goal: goal
        )

        self.context = AnalysisContext(
            draws: trainingDraws
        )

    }

    // MARK: - Neue Gewichtung

    func updateGoal(
        _ goal: OptimizationGoal
    ) {

        optimizer.updateGoal(goal)

    }

    // MARK: - Historie erweitern

    func add(draw: EuroJackpotDraw) {

        trainingDraws.append(draw)

        context.add(draw: draw)

    }

}
