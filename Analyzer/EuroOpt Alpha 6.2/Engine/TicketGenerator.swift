//
//  TicketGenerator.swift
//  EuroOpt
//
//  Alpha 6.2
//

import Foundation

final class TicketGenerator {

    private let scoreEngine = ScoreEngine()
    private let quickScore = QuickScore()
    private let mutator = SmartMutator()

    func generate(
        count: Int,
        draws: [EuroJackpotDraw]
    ) -> [Ticket] {

        print("🎲 Erzeuge \(count) Spielsysteme...")

        var candidates: [(ticket: Ticket, quick: Double)] = []

        while candidates.count < count {

            let ticket = randomTicket()

            guard isValid(ticket: ticket) else {
                continue
            }

            let quick = quickScore.calculate(
                ticket: ticket
            )

            candidates.append(
                (
                    ticket: ticket,
                    quick: quick
                )
            )

        }

        print("✅ Spielsysteme erzeugt: \(candidates.count)")

        candidates.sort {
            $0.quick > $1.quick
        }

        let survivorCount = max(
            count / 20,
            AppSettings.recommendationCount * 20
        )

        let survivors = Array(
            candidates.prefix(survivorCount)
        )

        print("🎯 Nach QuickScore übrig: \(survivors.count) Spielsysteme")

        let start = Date()

        let result = survivors.map {

            improve(
                ticket: $0.ticket,
                draws: draws
            )

        }

        let duration = Date().timeIntervalSince(start)

        print("✅ Hill Climbing beendet")
        print(String(format: "⏱ Hill Climbing: %.2f Sekunden", duration))

        return result

    }

    // MARK: - Hill Climbing

    private func improve(
        ticket: Ticket,
        draws: [EuroJackpotDraw]
    ) -> Ticket {

        var bestTicket = ticket

        var bestScore = scoreEngine.score(
            ticket: ticket,
            draws: draws
        )

        for _ in 0..<AppSettings.hillClimbingIterations {

            guard let candidate = mutator.mutate(
                ticket: bestTicket
            ) else {
                continue
            }

            guard isValid(ticket: candidate) else {
                continue
            }

            let score = scoreEngine.score(
                ticket: candidate,
                draws: draws
            )

            if score > bestScore {

                bestScore = score
                bestTicket = candidate

            }

        }

        return bestTicket

    }

    // MARK: - Zufallsticket

    private func randomTicket() -> Ticket {

        let numbers = Array(1...50)
            .shuffled()
            .prefix(5)
            .sorted()

        let euroNumbers = Array(1...12)
            .shuffled()
            .prefix(2)
            .sorted()

        return Ticket(
            numbers: Array(numbers),
            euroNumbers: Array(euroNumbers)
        )

    }

    // MARK: - Qualitätsprüfung

    private func isValid(
        ticket: Ticket
    ) -> Bool {

        let even = ticket.numbers.filter {
            $0.isMultiple(of: 2)
        }.count

        guard even >= AppSettings.minimumEvenNumbers &&
              even <= AppSettings.maximumEvenNumbers else {
            return false
        }

        let high = ticket.numbers.filter {
            $0 > 25
        }.count

        guard high >= AppSettings.minimumHighNumbers &&
              high <= AppSettings.maximumHighNumbers else {
            return false
        }

        let sum = ticket.numbers.reduce(0, +)

        guard sum >= AppSettings.minimumSum &&
              sum <= AppSettings.maximumSum else {
            return false
        }

        let sorted = ticket.numbers

        var consecutive = 1

        for i in 1..<sorted.count {

            if sorted[i] == sorted[i - 1] + 1 {

                consecutive += 1

                if consecutive > AppSettings.maximumConsecutiveNumbers {
                    return false
                }

            } else {

                consecutive = 1

            }

        }

        let gaps = zip(
            sorted,
            sorted.dropFirst()
        ).map {
            $1 - $0
        }

        let smallGaps = gaps.filter {
            $0 <= 2
        }.count

        guard smallGaps <= AppSettings.maximumSmallGaps else {
            return false
        }

        return true

    }

}
