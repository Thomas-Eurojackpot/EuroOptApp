//
//  ScoreNormalizer.swift
//  EuroOpt
//
//  Alpha 6.4
//

import Foundation

final class ScoreNormalizer {

    @inline(__always)
    func normalize(_ score: Double) -> Double {

        if score <= 0 {
            return 0
        }

        if score >= 100 {
            return 100
        }

        return score

    }

}
