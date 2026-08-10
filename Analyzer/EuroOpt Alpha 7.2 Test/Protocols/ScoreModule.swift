//
//  ScoreModule.swift
//  EuroOpt
//
//  Alpha 7.4
//

import Foundation

protocol ScoreModule {

    func calculate(
        numbers: [Int],
        euroNumbers: [Int],
        draws: [EuroJackpotDraw]
    ) -> Double

}
