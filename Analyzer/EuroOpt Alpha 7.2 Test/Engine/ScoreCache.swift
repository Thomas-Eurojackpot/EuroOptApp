//
//  ScoreCache.swift
//  EuroOpt
//
//  Alpha 7.3
//

import Foundation

final class ScoreCache {

    static let shared = ScoreCache()

    private init() {}

    private var cache: [String: Double] = [:]

    @inline(__always)
    func value(
        for key: String
    ) -> Double? {

        cache[key]

    }

    @inline(__always)
    func store(
        value: Double,
        for key: String
    ) {

        cache[key] = value

    }

    func clear() {

        cache.removeAll(
            keepingCapacity: true
        )

    }

    var count: Int {

        cache.count

    }

}
