import Foundation

struct AlphaFrequencyConfirmationResult {
    struct VariantResult {
        let label: String
        let totalPoints: Int
        let higherHits: Int
        let classes: [Int]
    }

    struct WindowResult {
        let windowNumber: Int
        let alphaProfileID: Int
        let points: [Int]
        let higherHits: [Int]
    }

    let holdoutDraws: Int
    let windows: [WindowResult]
    let variants: [VariantResult]
}

final class AlphaFrequencyBlendEngine {
    private let windowSize = 50
    private let windowCount = 6
    private let warmup = WeightSweepCore.warmup
    private let recommendationCount = 9
    private let variants: [(f2: Int, concentration: Int)] = [
        (0, 0),
        (0, 30)
    ]

    func run(draws: [EuroJackpotDraw]) -> AlphaFrequencyConfirmationResult? {
        let totalHoldout = windowSize * windowCount
        guard draws.count > warmup + totalHoldout else { return nil }

        let holdoutStart = draws.count - totalHoldout
        var windowResults: [AlphaFrequencyConfirmationResult.WindowResult] = []
        var accumulators = variants.map { _ in HitAccumulator() }

        for window in 0..<windowCount {
            let windowStart = holdoutStart + window * windowSize
            let windowEnd = windowStart + windowSize
            guard windowStart > warmup else { continue }

            let profiles = WeightSweepCore.makeProfiles()
            let winnerIndex = selectAlphaProfile(profiles: profiles, draws: draws, validationEnd: windowStart)
            let winner = profiles[winnerIndex]
            let generator = TicketGenerator()
            let candidateCount = WeightSweepCore.candidateCount()

            var windowAccumulators = variants.map { _ in HitAccumulator() }

            for index in windowStart..<windowEnd {
                let training = Array(draws.prefix(index))
                let target = draws[index]
                let candidates = generator.generate(
                    count: candidateCount,
                    draws: training,
                    goal: OptimizationGoal(),
                    hillClimbingIterations: 0
                )
                let cache = ScoreCache(draws: training)
                let alphaEngine = ScoreEngine(cache: cache, goal: winner.goal)
                let alphaScores = normalize(candidates.map { alphaEngine.score(ticket: $0) })
                let frequencyScores = normalize(frequencyScores(for: candidates, draws: training))
                let concentrationScores = normalize(mainConcentrationScores(for: candidates, draws: training))

                for (variantIndex, variant) in variants.enumerated() {
                    let f2 = Double(variant.f2) / 100.0
                    let concentration = Double(variant.concentration) / 100.0
                    let alpha = max(0.0, 1.0 - f2 - concentration)

                    let scores = candidates.indices.map { candidateIndex in
                        alpha * alphaScores[candidateIndex]
                            + f2 * frequencyScores[candidateIndex]
                            + concentration * concentrationScores[candidateIndex]
                    }

                    let tickets = select(
                        candidates: candidates,
                        scores: scores,
                        limit: recommendationCount
                    )

                    windowAccumulators[variantIndex].add(
                        tickets: tickets,
                        target: target
                    )
                    accumulators[variantIndex].add(
                        tickets: tickets,
                        target: target
                    )
                }
            }

            windowResults.append(.init(
                windowNumber: window + 1,
                alphaProfileID: winner.id,
                points: windowAccumulators.map { $0.points },
                higherHits: windowAccumulators.map { $0.higherHits }
            ))
        }

        let results = variants.indices.map { index in
            let variant = variants[index]
            let accumulator = accumulators[index]

            let label: String
            if variant.f2 == 0 && variant.concentration == 0 {
                label = "Alpha 7.5"
            } else if variant.concentration == 0 {
                label = "Alpha + F2 5%"
            } else if variant.f2 == 0 {
                label = "Alpha + Konzentration 30%"
            } else {
                label = "Alpha + F2 5% + Konzentration 30%"
            }

            return AlphaFrequencyConfirmationResult.VariantResult(
                label: label,
                totalPoints: accumulator.points,
                higherHits: accumulator.higherHits,
                classes: accumulator.classes
            )
        }

        print("===================================")
        print("🧪 ALPHA + F2-BESTÄTIGUNGSTEST")
        print("===================================")
        print("Fenster: \(windowCount) × \(windowSize) = \(totalHoldout) Ziehungen")
        print("Varianten: A=Alpha 7.5 | C=Alpha + Konzentration 30%")
        print("Jedes Fenster wählt sein Alpha-Profil nur aus der vorher verfügbaren Historie.")
        print("")
        for window in windowResults {
            let lines = variants.indices.map { index in
                let v = variants[index]
                return String(format: "%@ %4d P / 2+ %2d",
                    v.f2 == 0 && v.concentration == 0 ? "A" :
                    v.f2 == 5 && v.concentration == 0 ? "B" :
                    v.f2 == 0 && v.concentration == 30 ? "C" : "D",
                    window.points[index],
                    window.higherHits[index])
            }
            print("Fenster \(window.windowNumber) | P\(String(format: "%02d", window.alphaProfileID)) | " + lines.joined(separator: " | "))
        }
        print("")
        for result in results {
            print(String(format: "%-42@ | %4d Punkte | Ø %.3f | 2+ Haupt: %3d", result.label, result.totalPoints, Double(result.totalPoints) / Double(totalHoldout * recommendationCount), result.higherHits))
        }
        print("===================================")

        return AlphaFrequencyConfirmationResult(
            holdoutDraws: totalHoldout,
            windows: windowResults,
            variants: results
        )
    }

    private func selectAlphaProfile(profiles: [WeightSweepProfile], draws: [EuroJackpotDraw], validationEnd: Int) -> Int {
        guard validationEnd > warmup else { return 0 }
        let generator = TicketGenerator()
        let candidateCount = WeightSweepCore.candidateCount()
        var totals = Array(repeating: ValidationAggregate(), count: profiles.count)

        for index in warmup..<validationEnd {
            let training = Array(draws.prefix(index))
            let target = draws[index]
            let candidates = generator.generate(count: candidateCount, draws: training, goal: OptimizationGoal(), hillClimbingIterations: 0)
            let cache = ScoreCache(draws: training)
            let engines = profiles.map { ScoreEngine(cache: cache, goal: $0.goal) }
            for profileIndex in profiles.indices {
                let tickets = WeightSweepCore.bestTickets(candidates: candidates, scoreEngine: engines[profileIndex], limit: recommendationCount)
                totals[profileIndex].add(tickets: tickets, target: target)
            }
        }

        return profiles.indices.max(by: { totals[$0].score < totals[$1].score }) ?? 0
    }

    private func frequencyScores(for tickets: [Ticket], draws: [EuroJackpotDraw]) -> [Double] {
        let mainRank = rankMap(counts(draws: draws, range: 1...50, euro: false), range: 1...50)
        return tickets.map { ticket in
            ticket.numbers.reduce(0.0) { $0 + mainRank[$1, default: 0] } / 5.0
        }
    }

    private func mainConcentrationScores(for tickets: [Ticket], draws: [EuroJackpotDraw]) -> [Double] {
        let mainRank = rankMap(counts(draws: draws, range: 1...50, euro: false), range: 1...50)
        return tickets.map { ticket in
            let ranks = ticket.numbers.map { mainRank[$0, default: 0] }.sorted(by: >)
            guard ranks.count == 5 else { return 0.0 }
            return ranks[0] * 0.35 + ranks[1] * 0.25 + ranks[2] * 0.20 + ranks[3] * 0.12 + ranks[4] * 0.08
        }
    }

    private func counts(draws: [EuroJackpotDraw], range: ClosedRange<Int>, euro: Bool) -> [Int: Int] {
        var result = Dictionary(uniqueKeysWithValues: range.map { ($0, 0) })
        for draw in draws {
            let values = euro ? draw.euroNumbers : draw.numbers
            for value in values where range.contains(value) { result[value, default: 0] += 1 }
        }
        return result
    }

    private func rankMap(_ counts: [Int: Int], range: ClosedRange<Int>) -> [Int: Double] {
        let ranked = range.sorted {
            if counts[$0, default: 0] == counts[$1, default: 0] { return $0 < $1 }
            return counts[$0, default: 0] > counts[$1, default: 0]
        }
        let denominator = Double(max(1, ranked.count - 1))
        return Dictionary(uniqueKeysWithValues: ranked.enumerated().map { ($0.element, 1.0 - Double($0.offset) / denominator) })
    }

    private func normalize(_ values: [Double]) -> [Double] {
        guard let minValue = values.min(), let maxValue = values.max(), maxValue > minValue else { return values.map { _ in 0.5 } }
        return values.map { ($0 - minValue) / (maxValue - minValue) }
    }

    private func select(candidates: [Ticket], scores: [Double], limit: Int) -> [Ticket] {
        let ranked = candidates.indices.sorted {
            if scores[$0] == scores[$1] { return $0 < $1 }
            return scores[$0] > scores[$1]
        }
        var result: [Ticket] = []
        for index in ranked {
            if result.allSatisfy({ WeightSweepCore.commonNumbers($0, candidates[index]) < 3 }) {
                result.append(candidates[index])
                if result.count == limit { break }
            }
        }
        return result
    }

    private struct ValidationAggregate {
        var mainHits = 0
        var euroHits = 0
        var tickets = 0
        var score: Double { tickets > 0 ? Double(mainHits) / Double(tickets) - 0.50 + Double(euroHits) / Double(tickets) - 1.0 / 3.0 : 0 }
        mutating func add(tickets: [Ticket], target: EuroJackpotDraw) {
            for ticket in tickets {
                mainHits += Set(ticket.numbers).intersection(target.numbers).count
                euroHits += Set(ticket.euroNumbers).intersection(target.euroNumbers).count
            }
            self.tickets += tickets.count
        }
    }

    private struct HitAccumulator {
        var classes = Array(repeating: 0, count: 18)
        var mainHits = 0
        var euroHits = 0
        var tickets = 0
        var points: Int { classes.enumerated().reduce(0) { total, item in
            let main = item.offset / 3
            let euro = item.offset % 3
            return total + main * main * item.element + euro * item.element
        } }
        var higherHits: Int { classes.enumerated().filter { $0.offset / 3 >= 2 }.reduce(0) { $0 + $1.element } }

        mutating func add(tickets: [Ticket], target: EuroJackpotDraw) {
            for ticket in tickets {
                let main = Set(ticket.numbers).intersection(target.numbers).count
                let euro = Set(ticket.euroNumbers).intersection(target.euroNumbers).count
                classes[main * 3 + euro] += 1
                mainHits += main
                euroHits += euro
            }
            self.tickets += tickets.count
        }
    }
}
