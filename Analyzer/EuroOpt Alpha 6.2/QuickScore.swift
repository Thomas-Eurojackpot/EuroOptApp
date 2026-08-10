//
//  QuickScore.swift
//  EuroOpt
//
//  Alpha 6.1
//

import Foundation

final class QuickScore {

    func calculate(
        ticket: Ticket
    ) -> Double {

        var score = 0.0

        let sum = ticket.numbers.reduce(0, +)

        if sum >= AppSettings.minimumSum &&
            sum <= AppSettings.maximumSum {

            score += 30

        }

        let even = ticket.numbers.filter {
            $0.isMultiple(of: 2)
        }.count

        if even >= AppSettings.minimumEvenNumbers &&
            even <= AppSettings.maximumEvenNumbers {

            score += 20

        }

        let high = ticket.numbers.filter {
            $0 > 25
        }.count

        if high >= AppSettings.minimumHighNumbers &&
            high <= AppSettings.maximumHighNumbers {

            score += 20

        }

        let sorted = ticket.numbers

        var consecutive = 1

        for i in 1..<sorted.count {

            if sorted[i] == sorted[i - 1] + 1 {

                consecutive += 1

            } else {

                consecutive = 1

            }

        }

        if consecutive <= AppSettings.maximumConsecutiveNumbers {

            score += 15

        }

        let gaps = zip(
            sorted,
            sorted.dropFirst()
        ).map { $1 - $0 }

        let smallGaps = gaps.filter {
            $0 <= 2
        }.count

        if smallGaps <= AppSettings.maximumSmallGaps {

            score += 15

        }

        return score

    }

}
