//
//  ConcentrationDiagnostic.swift
//  EuroOpt
//
//  Alpha 7.6 concentration diagnostic
//

import Foundation

struct ConcentrationDiagnostic {

    private let limits: [(name: String, fraction: Double)] = [
        ("C20", 0.20),
        ("C30", 0.30),
        ("C40", 0.40),
        ("C50", 0.50)
    ]

    func run(
        candidates: [Ticket],
        draws: [EuroJackpotDraw],
        limit: Int = 9
    ) {
        guard !candidates.isEmpty else {
            print("❌ Konzentrationsdiagnose: keine Kandidaten")
            return
        }

        let optimizer = OptimizerEngine()
        let ranked = optimizer.rankedTicketsForDiagnostic(
            from: candidates,
            draws: draws
        )

        print("================================")
        print("🔬 ALPHA 7.6 KONZENTRATIONSTEST")
        print("================================")
        print("Kandidaten: \(candidates.count)")
        print("")

        for variant in limits {
            let selected = applyCap(
                ranked: ranked,
                maximumFraction: variant.fraction
            )

            let tickets = diverseTickets(
                ranked: selected,
                limit: limit
            )

            print(String(format: "%-3@  max %.0f%%  Pool %2d  Tickets %2d  Hauptzahlen %2d / 50",
                         variant.name,
                         variant.fraction * 100,
                         selected.count,
                         tickets.count,
                         distinctMainNumbers(tickets)))
        }

        print("================================")
    }

    private func applyCap(
        ranked: [(ticket: Ticket, score: Double)],
        maximumFraction: Double
    ) -> [(ticket: Ticket, score: Double)] {

        let poolSize = ranked.count
        let maximum = max(1, Int(ceil(Double(poolSize) * maximumFraction)))
        var frequencies = Array(repeating: 0, count: 51)
        var result: [(ticket: Ticket, score: Double)] = []
        result.reserveCapacity(poolSize)

        for candidate in ranked {
            var allowed = true

            for number in candidate.ticket.numbers where (1...50).contains(number) {
                if frequencies[number] >= maximum {
                    allowed = false
                    break
                }
            }

            if allowed {
                result.append(candidate)
                for number in candidate.ticket.numbers where (1...50).contains(number) {
                    frequencies[number] += 1
                }
            }
        }

        return result
    }

    private func diverseTickets(
        ranked: [(ticket: Ticket, score: Double)],
        limit: Int
    ) -> [Ticket] {

        var result: [Ticket] = []
        result.reserveCapacity(limit)

        for candidate in ranked {
            if result.allSatisfy({ commonNumbers($0, candidate.ticket) < 3 }) {
                result.append(candidate.ticket)
            }

            if result.count == limit {
                break
            }
        }

        return result
    }

    private func distinctMainNumbers(_ tickets: [Ticket]) -> Int {
        Set(tickets.flatMap(\.numbers)).count
    }

    private func commonNumbers(_ lhs: Ticket, _ rhs: Ticket) -> Int {
        Set(lhs.numbers).intersection(rhs.numbers).count
    }
}
