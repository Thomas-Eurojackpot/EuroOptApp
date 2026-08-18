//
//  OptimizerEngine.swift
//  EuroOpt
//
//  Alpha 7.6
//  Alpha + Hauptzahl-Konzentration 30 %
//

import Foundation

final class OptimizerEngine {

    private let scoreEngine: ScoreEngine
    private let alphaWeight = 0.70
    private let concentrationWeight = 0.30

    init(goal: OptimizationGoal = OptimizationGoal()) {
        self.scoreEngine = ScoreEngine(goal: goal)
    }

    func updateGoal(_ goal: OptimizationGoal) {
        scoreEngine.updateGoal(goal)
    }

    func bestTickets(
        from candidates: [Ticket],
        draws: [EuroJackpotDraw],
        goal: OptimizationGoal? = nil,
        limit: Int = 8
    ) -> [(ticket: Ticket, score: Double)] {

        if let goal { scoreEngine.updateGoal(goal) }

        print("🎯 Alpha 7.6 bewertet \(candidates.count) Tickets")
        print("⚖️ Gewichtung: 70 % Alpha + 30 % Konzentration")

        guard !candidates.isEmpty else { return [] }

        let ranked = ranked(from: candidates, draws: draws)

        let keepCount = min(max(limit * 4, 32), ranked.count)
        let diagnosticIndices = Array(ranked.prefix(keepCount))

        printDiversityDiagnostics(
            candidates: candidates,
            indices: diagnosticIndices.map(\.index)
        )

        if candidates.count == 500 {
            runConcentrationDiagnostic(
                candidates: candidates,
                ranked: ranked,
                limit: limit
            )
        }

        if ProcessInfo.processInfo.environment["EUROOPT_C40_HOLDOUT"] == "1" {
            runC40HoldoutComparison(
                draws: draws,
                recommendationCount: limit
            )
        }

        var result: [(ticket: Ticket, score: Double)] = []
        result.reserveCapacity(limit)

        for item in ranked.prefix(keepCount) {
            let candidate = candidates[item.index]
            var different = true

            for existing in result {
                if commonNumbers(existing.ticket, candidate) >= 3 {
                    different = false
                    break
                }
            }

            if different {
                result.append((ticket: candidate, score: item.score))
                if result.count == limit { break }
            }
        }

        print("✅ Alpha 7.6 Optimizer fertig (\(result.count) Tickets)")
        return result
    }

    func rankedTicketsForDiagnostic(
        from candidates: [Ticket],
        draws: [EuroJackpotDraw]
    ) -> [(ticket: Ticket, score: Double)] {
        guard !candidates.isEmpty else { return [] }
        return ranked(from: candidates, draws: draws).map {
            (ticket: candidates[$0.index], score: $0.score)
        }
    }

    private func ranked(
        from candidates: [Ticket],
        draws: [EuroJackpotDraw]
    ) -> [(index: Int, score: Double)] {

        let alphaScores = candidates.map {
            scoreEngine.score(ticket: $0, draws: draws)
        }

        let concentrationScores = mainConcentrationScores(
            for: candidates,
            draws: draws
        )

        let normalizedAlpha = normalize(alphaScores)
        let normalizedConcentration = normalize(concentrationScores)

        let blendedScores = candidates.indices.map { index in
            alphaWeight * normalizedAlpha[index]
                + concentrationWeight * normalizedConcentration[index]
        }

        return candidates.indices.sorted {
            if blendedScores[$0] == blendedScores[$1] { return $0 < $1 }
            return blendedScores[$0] > blendedScores[$1]
        }.map {
            (index: $0, score: blendedScores[$0])
        }
    }

    private func printDiversityDiagnostics(
        candidates: [Ticket],
        indices: [Int]
    ) {
        guard !indices.isEmpty else { return }

        var frequencies = Array(repeating: 0, count: 51)

        for index in indices {
            for number in candidates[index].numbers where (1...50).contains(number) {
                frequencies[number] += 1
            }
        }

        let usedNumbers = frequencies.enumerated()
            .filter { $0.offset > 0 && $0.element > 0 }

        let sorted = usedNumbers.sorted {
            if $0.element == $1.element { return $0.offset < $1.offset }
            return $0.element > $1.element
        }

        print("--------------------------------")
        print("🔎 DIVERSITÄTS-DIAGNOSE ALPHA 7.6")
        print("Top-Kandidaten im Auswahlpool: \(indices.count)")
        print("Verschiedene Hauptzahlen: \(usedNumbers.count) / 50")
        print("Häufigste Hauptzahlen:")

        for item in sorted.prefix(15) {
            print(String(format: "   %2d → %2d Kandidaten", item.offset, item.element))
        }

        let probeNumbers = [5, 28, 40]
        print("Prüfzahlen:")
        for number in probeNumbers {
            print(String(format: "   %2d → %2d Kandidaten", number, frequencies[number]))
        }
        print("--------------------------------")
    }

    private func runConcentrationDiagnostic(
        candidates: [Ticket],
        ranked: [(index: Int, score: Double)],
        limit: Int
    ) {
        let poolSize = min(max(limit * 4, 32), ranked.count)
        let basePool = Array(ranked.prefix(poolSize))
        let variants: [(String, Double)] = [
            ("C20", 0.20),
            ("C30", 0.30),
            ("C40", 0.40),
            ("C50", 0.50)
        ]

        print("================================")
        print("🔬 ALPHA 7.6 KONZENTRATIONSTEST")
        print("================================")
        print("Basis-Pool: \(basePool.count) Kandidaten")

        for (name, fraction) in variants {
            let maximum = max(1, Int(ceil(Double(basePool.count) * fraction)))
            var frequencies = Array(repeating: 0, count: 51)
            var selected: [(index: Int, score: Double)] = []

            for item in basePool {
                let allowed = item.index >= 0 && candidates[item.index].numbers.allSatisfy { number in
                    guard (1...50).contains(number) else { return true }
                    return frequencies[number] < maximum
                }

                if allowed {
                    selected.append(item)
                    for number in candidates[item.index].numbers where (1...50).contains(number) {
                        frequencies[number] += 1
                    }
                }
            }

            var tickets: [Ticket] = []
            for item in selected {
                let ticket = candidates[item.index]
                if tickets.allSatisfy({ commonNumbers($0, ticket) < 3 }) {
                    tickets.append(ticket)
                }
                if tickets.count == limit { break }
            }

            let distinct = Set(tickets.flatMap(\.numbers)).count
            let maxUsed = frequencies.dropFirst().max() ?? 0

            print(String(format: "%@  max %2d/%2d  Pool %2d  Tickets %2d  Hauptzahlen %2d/50  MaxFreq %2d",
                         name,
                         maximum,
                         basePool.count,
                         selected.count,
                         tickets.count,
                         distinct,
                         maxUsed))
        }
        print("================================")
    }

    func runC40HoldoutComparison(
        draws: [EuroJackpotDraw],
        recommendationCount: Int
    ) {
        guard draws.count > 140 else { return }

        let start = Date()
        let candidateCount = max(AppSettings.backtestCandidateCount + 1, 301)
        let firstIndex = 100
        let generator = TicketGenerator()

        var originalHits = 0
        var originalEuroHits = 0
        var originalTickets = 0
        var c40Hits = 0
        var c40EuroHits = 0
        var c40Tickets = 0

        print("")
        print("===================================")
        print("🧪 ALPHA 7.6 C40 HOLDOUT-VERGLEICH")
        print("===================================")
        print("Ziehungen           : \(draws.count - firstIndex)")
        print("Kandidaten je Test  : \(candidateCount)")
        print("Empfehlungen        : \(recommendationCount)")
        print("Basis-Pool          : 36")
        print("C40-Limit           : 15 Vorkommen je Hauptzahl")
        print("🔒 C40 wird nur bei der Ticket-Auswahl angewendet.")
        print("")

        for index in firstIndex..<draws.count {
            let trainingDraws = Array(draws.prefix(index))
            let targetDraw = draws[index]
            let candidates = generator.generate(
                count: candidateCount,
                draws: trainingDraws,
                goal: OptimizationGoal(),
                hillClimbingIterations: 0
            )

            let ranked = ranked(from: candidates, draws: trainingDraws)
            let basePool = Array(ranked.prefix(min(36, ranked.count)))

            let original = diverseTickets(
                ranked: basePool,
                candidates: candidates,
                limit: recommendationCount
            )

            let cappedPool = concentrationCappedPool(
                ranked: basePool,
                candidates: candidates,
                maximum: 15
            )

            let c40 = diverseTickets(
                ranked: cappedPool,
                candidates: candidates,
                limit: recommendationCount
            )

            for ticket in original {
                originalHits += Set(ticket.numbers).intersection(targetDraw.numbers).count
                originalEuroHits += Set(ticket.euroNumbers).intersection(targetDraw.euroNumbers).count
            }
            originalTickets += original.count

            for ticket in c40 {
                c40Hits += Set(ticket.numbers).intersection(targetDraw.numbers).count
                c40EuroHits += Set(ticket.euroNumbers).intersection(targetDraw.euroNumbers).count
            }
            c40Tickets += c40.count

            let current = index - firstIndex + 1
            if current.isMultiple(of: 50) {
                print("... Holdout \(current) / \(draws.count - firstIndex)")
            }
        }

        let originalMain = originalTickets > 0 ? Double(originalHits) / Double(originalTickets) : 0
        let originalEuro = originalTickets > 0 ? Double(originalEuroHits) / Double(originalTickets) : 0
        let c40Main = c40Tickets > 0 ? Double(c40Hits) / Double(c40Tickets) : 0
        let c40Euro = c40Tickets > 0 ? Double(c40EuroHits) / Double(c40Tickets) : 0

        print("")
        print("-----------------------------------")
        print("ALPHA 7.6 ORIGINAL")
        print("-----------------------------------")
        print(String(format: "Ø Haupttreffer      : %.3f", originalMain))
        print(String(format: "Ø Eurotreffer       : %.3f", originalEuro))
        print("-----------------------------------")
        print("ALPHA 7.6 + C40")
        print("-----------------------------------")
        print(String(format: "Ø Haupttreffer      : %.3f", c40Main))
        print(String(format: "Ø Eurotreffer       : %.3f", c40Euro))
        print("-----------------------------------")
        print("C40 vs. Original")
        print(String(format: "Δ Haupttreffer      : %+.3f", c40Main - originalMain))
        print(String(format: "Δ Eurotreffer       : %+.3f", c40Euro - originalEuro))
        print(String(format: "Kombiniertes Δ      : %+.3f", (c40Main - originalMain) + (c40Euro - originalEuro)))
        print(String(format: "⏱ C40-Holdout: %.2f Sekunden", Date().timeIntervalSince(start)))
        print("===================================")
    }

    private func concentrationCappedPool(
        ranked: [(index: Int, score: Double)],
        candidates: [Ticket],
        maximum: Int
    ) -> [(index: Int, score: Double)] {
        var frequencies = Array(repeating: 0, count: 51)
        var result: [(index: Int, score: Double)] = []
        result.reserveCapacity(ranked.count)

        for item in ranked {
            let allowed = candidates[item.index].numbers.allSatisfy { number in
                guard (1...50).contains(number) else { return true }
                return frequencies[number] < maximum
            }

            if allowed {
                result.append(item)
                for number in candidates[item.index].numbers where (1...50).contains(number) {
                    frequencies[number] += 1
                }
            }
        }

        return result
    }

    private func diverseTickets(
        ranked: [(index: Int, score: Double)],
        candidates: [Ticket],
        limit: Int
    ) -> [Ticket] {
        var result: [Ticket] = []
        result.reserveCapacity(limit)

        for item in ranked {
            let ticket = candidates[item.index]
            if result.allSatisfy({ commonNumbers($0, ticket) < 3 }) {
                result.append(ticket)
            }
            if result.count == limit { break }
        }
        return result
    }

    private func mainConcentrationScores(
        for tickets: [Ticket],
        draws: [EuroJackpotDraw]
    ) -> [Double] {

        let mainRank = rankMap(
            counts(draws: draws, range: 1...50),
            range: 1...50
        )

        return tickets.map { ticket in
            let ranks = ticket.numbers
                .map { mainRank[$0, default: 0] }
                .sorted(by: >)

            guard ranks.count == 5 else { return 0.0 }

            return ranks[0] * 0.35
                + ranks[1] * 0.25
                + ranks[2] * 0.20
                + ranks[3] * 0.12
                + ranks[4] * 0.08
        }
    }

    private func counts(
        draws: [EuroJackpotDraw],
        range: ClosedRange<Int>
    ) -> [Int: Int] {

        var result = Dictionary(uniqueKeysWithValues: range.map { ($0, 0) })

        for draw in draws {
            for value in draw.numbers where range.contains(value) {
                result[value, default: 0] += 1
            }
        }
        return result
    }

    private func rankMap(
        _ counts: [Int: Int],
        range: ClosedRange<Int>
    ) -> [Int: Double] {

        let ranked = range.sorted {
            if counts[$0, default: 0] == counts[$1, default: 0] { return $0 < $1 }
            return counts[$0, default: 0] > counts[$1, default: 0]
        }

        let denominator = Double(max(1, ranked.count - 1))

        return Dictionary(uniqueKeysWithValues: ranked.enumerated().map {
            ($0.element, 1.0 - Double($0.offset) / denominator)
        })
    }

    private func normalize(_ values: [Double]) -> [Double] {
        guard let minValue = values.min(),
              let maxValue = values.max(),
              maxValue > minValue else {
            return values.map { _ in 0.5 }
        }

        return values.map { ($0 - minValue) / (maxValue - minValue) }
    }

    @inline(__always)
    private func commonNumbers(_ lhs: Ticket, _ rhs: Ticket) -> Int {
        var count = 0
        for number in lhs.numbers {
            if rhs.numbers.contains(number) {
                count += 1
                if count >= 3 { return count }
            }
        }
        return count
    }
}
