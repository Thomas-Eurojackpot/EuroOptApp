//
//  AnalysisCache.swift
//  EuroOpt
//
//  Alpha 7.4
//

import Foundation

final class AnalysisCache {

    static let shared = AnalysisCache()

    private init() {}

    private var contexts: [Int: AnalysisContext] = [:]

    func context(
        for draws: [EuroJackpotDraw]
    ) -> AnalysisContext {

        let key = draws.count

        if let context = contexts[key] {
            return context
        }

        let context = AnalysisContext(
            draws: draws
        )

        contexts[key] = context

        return context

    }

    func clear() {

        contexts.removeAll()

    }

}
