//
//  ScoreEngine.swift
//  EuroOpt
//
//  Alpha 7.4 Test - Performance
//

import Foundation

// MARK: - Shared immutable analysis cache

/// Builds the historical statistics once and reuses them for every ticket score.
///
/// This is the main performance optimization: the old implementation repeatedly
/// walked the complete draw history from inside individual score modules.
/// Ticket scoring now only performs small O(ticket-size) lookups against this cache.
final class ScoreCache {

    let drawCount: Int

    let frequencies: [Int: Int]
    let minimumFrequency: Int
    let maximumFrequency: Int

    let pairFrequencies: [Set<Int>: Int]
    let maximumPairFrequency: Int

    let evenOddDistribution: [String: Int]
    let maximumEvenOddFrequency: Int

    let highLowDistribution: [String: Int]
    let maximumHighLowFrequency: Int

    let sumDistribution: [Int: Int]
    let maximumSumFrequency: Int

    let gapDistribution: [String: Int]
    let maximumGapFrequency: Int

    private let firstSignature: DrawSignature?
    private let lastSignature: DrawSignature?

    init(draws: [EuroJackpotDraw]) {

        drawCount = draws.count

        var frequencyCounter: [Int: Int] = [:]
        for number in 1...50 {
            frequencyCounter[number] = 0
        }

        var pairCounter: [Set<Int>: Int] = [:]
        var evenOddCounter: [String: Int] = [:]
        var highLowCounter: [String: Int] = [:]
        var sumCounter: [Int: Int] = [:]
        var gapCounter: [String: Int] = [:]

        for draw in draws {

            for number in draw.numbers {
                frequencyCounter[number, default: 0] += 1
            }

            let numbers = draw.numbers.sorted()

            for i in 0..<numbers.count {
                for j in (i + 1)..<numbers.count {
                    let pair: Set<Int> = [numbers[i], numbers[j]]
                    pairCounter[pair, default: 0] += 1
                }
            }

            let even = numbers.filter { $0.isMultiple(of: 2) }.count
            let odd = numbers.count - even
            evenOddCounter["\(even):\(odd)", default: 0] += 1

            let low = numbers.filter { $0 <= 25 }.count
            let high = numbers.count - low
            highLowCounter["\(low):\(high)", default: 0] += 1

            let sum = numbers.reduce(0, +)
            sumCounter[sum, default: 0] += 1

            let gaps = zip(numbers, numbers.dropFirst())
                .map { $1 - $0 }
                .map(String.init)
                .joined(separator: "-")

            gapCounter[gaps, default: 0] += 1
        }

        frequencies = frequencyCounter
        minimumFrequency = frequencyCounter.values.min() ?? 0
        maximumFrequency = frequencyCounter.values.max() ?? 0

        pairFrequencies = pairCounter
        maximumPairFrequency = pairCounter.values.max() ?? 0

        evenOddDistribution = evenOddCounter
        maximumEvenOddFrequency = evenOddCounter.values.max() ?? 0

        highLowDistribution = highLowCounter
        maximumHighLowFrequency = highLowCounter.values.max() ?? 0

        sumDistribution = sumCounter
        maximumSumFrequency = sumCounter.values.max() ?? 0

        gapDistribution = gapCounter
        maximumGapFrequency = gapCounter.values.max() ?? 0

        firstSignature = draws.first.map(DrawSignature.init)
        lastSignature = draws.last.map(DrawSignature.init)
    }

    func matches(_ draws: [EuroJackpotDraw]) -> Bool {

        guard draws.count == drawCount else {
            return false
        }

        guard
            draws.first.map(DrawSignature.init) == firstSignature,
            draws.last.map(DrawSignature.init) == lastSignature
        else {
            return false
        }

        return true
    }
}

private struct DrawSignature: Equatable {
    let date: Date
    let numbers: [Int]
    let euroNumbers: [Int]

    init(draw: EuroJackpotDraw) {
        date = draw.date
        numbers = draw.numbers
        euroNumbers = draw.euroNumbers
    }
}

// MARK: - Score engine

final class ScoreEngine {

    private var cache: ScoreCache
    private var goal: OptimizationGoal

    init(goal: OptimizationGoal = OptimizationGoal()) {
        self.goal = goal
        self.cache = ScoreCache(draws: [])
    }

    init(cache: ScoreCache, goal: OptimizationGoal = OptimizationGoal()) {
        self.goal = goal
        self.cache = cache
    }

    func updateGoal(_ goal: OptimizationGoal) {
        self.goal = goal
    }

    @inline(__always)
    func score(
        ticket: Ticket,
        draws: [EuroJackpotDraw]
    ) -> Double {

        if !cache.matches(draws) {
            cache = ScoreCache(draws: draws)
        }

        return score(ticket: ticket)
    }

    /// Scores against the already prepared cache. Safe to use from parallel
    /// workers as long as the cache is not replaced while scoring.
    @inline(__always)
    func score(ticket: Ticket) -> Double {

        let totalWeight =
            goal.frequencyWeight +
            goal.pairWeight +
            goal.evenOddWeight +
            goal.highLowWeight +
            goal.sumWeight +
            goal.gapWeight

        guard totalWeight > 0 else {
            return 0
        }

        let numbers = ticket.numbers
        var weightedScore = 0.0

        // Frequency
        if cache.maximumFrequency > cache.minimumFrequency {

            var totalFrequency = 0
            for number in numbers {
                totalFrequency += cache.frequencies[number] ?? cache.minimumFrequency
            }

            let minimumScore = cache.minimumFrequency * numbers.count
            let maximumScore = cache.maximumFrequency * numbers.count

            weightedScore +=
                Double(totalFrequency - minimumScore)
                / Double(maximumScore - minimumScore)
                * 100.0
                * goal.frequencyWeight
        }

        // Pairs
        if cache.maximumPairFrequency > 0 && numbers.count >= 2 {

            let sortedNumbers = numbers.sorted()
            var totalFrequency = 0

            for i in 0..<(sortedNumbers.count - 1) {
                let first = sortedNumbers[i]

                for j in (i + 1)..<sortedNumbers.count {
                    let pair: Set<Int> = [first, sortedNumbers[j]]
                    totalFrequency += cache.pairFrequencies[pair] ?? 0
                }
            }

            weightedScore +=
                (Double(totalFrequency) / 10.0)
                / Double(cache.maximumPairFrequency)
                * 100.0
                * goal.pairWeight
        }

        // Even / Odd
        if cache.maximumEvenOddFrequency > 0 {

            let even = numbers.filter { $0.isMultiple(of: 2) }.count
            let odd = numbers.count - even
            let key = "\(even):\(odd)"
            let count = cache.evenOddDistribution[key] ?? 0

            weightedScore +=
                Double(count) / Double(cache.maximumEvenOddFrequency)
                * 100.0
                * goal.evenOddWeight
        }

        // High / Low
        if cache.maximumHighLowFrequency > 0 {

            let low = numbers.filter { $0 <= 25 }.count
            let high = numbers.count - low
            let key = "\(low):\(high)"
            let count = cache.highLowDistribution[key] ?? 0

            weightedScore +=
                Double(count) / Double(cache.maximumHighLowFrequency)
                * 100.0
                * goal.highLowWeight
        }

        // Sum
        if cache.maximumSumFrequency > 0 {

            let sum = numbers.reduce(0, +)
            let count = cache.sumDistribution[sum] ?? 0

            weightedScore +=
                Double(count) / Double(cache.maximumSumFrequency)
                * 100.0
                * goal.sumWeight
        }

        // Gap pattern
        if cache.maximumGapFrequency > 0 && numbers.count >= 2 {

            let sortedNumbers = numbers.sorted()
            let key = zip(sortedNumbers, sortedNumbers.dropFirst())
                .map { String($1 - $0) }
                .joined(separator: "-")

            let count = cache.gapDistribution[key] ?? 0

            weightedScore +=
                Double(count) / Double(cache.maximumGapFrequency)
                * 100.0
                * goal.gapWeight
        }

        return weightedScore / totalWeight
    }
}
