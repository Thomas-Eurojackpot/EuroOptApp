//
//  BacktestSession.swift
//  EuroOpt
//
//  Alpha 6.6
//

import Foundation

final class BacktestSession {

    // MARK: - Properties

    let generator = TicketGenerator()
    let optimizer = OptimizerEngine()

    private(set) var trainingDraws: [EuroJackpotDraw]

    let context: AnalysisContext

    // MARK: - Initialisierung

    init(trainingDraws: [EuroJackpotDraw]) {

        self.trainingDraws = trainingDraws

        self.context = AnalysisContext(
            draws: trainingDraws
        )

    }

    // MARK: - Historie erweitern

    func add(draw: EuroJackpotDraw) {

        trainingDraws.append(draw)

        context.add(draw: draw)

    }

}
