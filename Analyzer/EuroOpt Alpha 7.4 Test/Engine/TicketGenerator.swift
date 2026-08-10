//
//  TicketGenerator.swift
//  EuroOpt
//
//  Alpha 7.4 Test - Performance
//

import Foundation

final class TicketGenerator {

    private let quickScore = QuickScore()

    func generate(
        count: Int,
        draws: [EuroJackpotDraw],
        goal: OptimizationGoal = OptimizationGoalStore.shared.currentGoal,
        hillClimbingIterations: Int = AppSettings.hillClimbingIterations
    ) -> [Ticket] {

        print("🎲 Erzeuge \(count) Spielsysteme...")

        var candidates: [(ticket: Ticket, quick: Double)] = []
        candidates.reserveCapacity(count)

        while candidates.count < count {
            let ticket = randomTicket()
            guard isValid(ticket: ticket) else { continue }
            candidates.append((ticket: ticket, quick: quickScore.calculate(ticket: ticket)))
        }

        print("✅ Spielsysteme erzeugt: \(candidates.count)")

        candidates.sort { $0.quick > $1.quick }

        let survivorCount: Int
        if count == AppSettings.backtestCandidateCount {
            survivorCount = min(AppSettings.backtestSurvivorCount, candidates.count)
        } else {
            survivorCount = max(count / 20, AppSettings.recommendationCount * 20)
        }

        let survivors = Array(candidates.prefix(survivorCount))
        print("🎯 Nach QuickScore übrig: \(survivors.count) Spielsysteme")

        let start = Date()
        let scoreCache = ScoreCache(draws: draws)
        var result = Array<Ticket?>(repeating: nil, count: survivors.count)
        let resultLock = NSLock()

        DispatchQueue.concurrentPerform(iterations: survivors.count) { index in
            let scoreEngine = ScoreEngine(cache: scoreCache, goal: goal)
            let mutator = SmartMutator()

            let improved = improve(
                ticket: survivors[index].ticket,
                scoreEngine: scoreEngine,
                mutator: mutator,
                iterations: hillClimbingIterations
            )

            resultLock.lock()
            result[index] = improved
            resultLock.unlock()
        }

        let finalResult = result.compactMap { $0 }
        let duration = Date().timeIntervalSince(start)

        print("✅ Hill Climbing beendet")
        print(String(format: "⏱ Hill Climbing: %.2f Sekunden", duration))

        return finalResult
    }

    @inline(__always)
    private func improve(
        ticket: Ticket,
        scoreEngine: ScoreEngine,
        mutator: SmartMutator,
        iterations: Int
    ) -> Ticket {

        var bestTicket = ticket
        var bestScore = scoreEngine.score(ticket: ticket)

        for _ in 0..<iterations {
            guard let candidate = mutator.mutate(ticket: bestTicket),
                  isValid(ticket: candidate) else { continue }

            let score = scoreEngine.score(ticket: candidate)
            if score > bestScore {
                bestScore = score
                bestTicket = candidate
            }
        }

        return bestTicket
    }

    @inline(__always)
    private func randomTicket() -> Ticket {
        var numbers = Set<Int>()
        while numbers.count < 5 { numbers.insert(Int.random(in: 1...50)) }

        var euroNumbers = Set<Int>()
        while euroNumbers.count < 2 { euroNumbers.insert(Int.random(in: 1...12)) }

        return Ticket(numbers: numbers.sorted(), euroNumbers: euroNumbers.sorted())
    }

    @inline(__always)
    private func isValid(ticket: Ticket) -> Bool {
        let numbers = ticket.numbers
        var even = 0
        var high = 0
        var sum = 0
        var consecutive = 1
        var smallGaps = 0

        for i in numbers.indices {
            let value = numbers[i]
            sum += value
            if value.isMultiple(of: 2) { even += 1 }
            if value > 25 { high += 1 }

            if i > 0 {
                let gap = value - numbers[i - 1]
                if gap == 1 {
                    consecutive += 1
                    if consecutive > AppSettings.maximumConsecutiveNumbers { return false }
                } else {
                    consecutive = 1
                }
                if gap <= 2 { smallGaps += 1 }
            }
        }

        guard even >= AppSettings.minimumEvenNumbers && even <= AppSettings.maximumEvenNumbers else { return false }
        guard high >= AppSettings.minimumHighNumbers && high <= AppSettings.maximumHighNumbers else { return false }
        guard sum >= AppSettings.minimumSum && sum <= AppSettings.maximumSum else { return false }
        guard smallGaps <= AppSettings.maximumSmallGaps else { return false }
        return true
    }
}
