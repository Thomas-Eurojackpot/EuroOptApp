import Foundation

struct AlphaFrequencyBlendResult {
    struct VariantResult {
        let label: String
        let frequencyPercent: Int
        let concentrationPercent: Int
        let classes: [Int]
        let totalPoints: Int
        let mainHits: Int
        let euroHits: Int
        let higherHits: Int
    }
    let holdoutDraws: Int
    let alphaProfileID: Int
    let variants: [VariantResult]
}

final class AlphaFrequencyBlendEngine {
    private let holdoutCount = 50
    private let warmup = WeightSweepCore.warmup
    private let recommendationCount = 9
    private let variants: [(Int, Int)] = [
        (0, 0),
        (5, 0),
        (5, 10),
        (5, 20),
        (5, 30),
        (5, 40),
        (5, 50),
        (15, 0),
        (15, 20),
        (15, 40)
    ]

    func run(draws: [EuroJackpotDraw]) -> AlphaFrequencyBlendResult? {
        guard draws.count > warmup + holdoutCount else { return nil }
        let holdoutStart = draws.count - holdoutCount
        let validationEnd = warmup + (holdoutStart - warmup) / 2
        let profiles = WeightSweepCore.makeProfiles()
        let generator = TicketGenerator()
        let candidateCount = WeightSweepCore.candidateCount()
        var validationTotals = Array(repeating: ValidationAggregate(), count: profiles.count)

        for index in warmup..<validationEnd {
            let training = Array(draws.prefix(index))
            let target = draws[index]
            let candidates = generator.generate(count: candidateCount, draws: training, goal: OptimizationGoal(), hillClimbingIterations: 0)
            let cache = ScoreCache(draws: training)
            let engines = profiles.map { ScoreEngine(cache: cache, goal: $0.goal) }
            for profileIndex in profiles.indices {
                let tickets = WeightSweepCore.bestTickets(candidates: candidates, scoreEngine: engines[profileIndex], limit: recommendationCount)
                validationTotals[profileIndex].add(tickets: tickets, target: target)
            }
        }

        guard let winnerIndex = profiles.indices.max(by: { validationTotals[$0].score < validationTotals[$1].score }) else { return nil }
        let winner = profiles[winnerIndex]
        var accumulators = variants.map { _ in HitAccumulator() }

        for index in holdoutStart..<draws.count {
            let training = Array(draws.prefix(index))
            let target = draws[index]
            let candidates = generator.generate(count: candidateCount, draws: training, goal: OptimizationGoal(), hillClimbingIterations: 0)
            let cache = ScoreCache(draws: training)
            let alphaEngine = ScoreEngine(cache: cache, goal: winner.goal)
            let alphaNormalized = normalize(candidates.map { alphaEngine.score(ticket: $0) })
            let frequency = frequencyScores(for: candidates, draws: training)
            let frequencyNormalized = normalize(frequency)
            let concentration = mainConcentrationScores(for: candidates, draws: training)
            let concentrationNormalized = normalize(concentration)

            for (variantIndex, variant) in variants.enumerated() {
                let f2Blend = Double(variant.0) / 100.0
                let concentrationBlend = Double(variant.1) / 100.0
                let blended = candidates.indices.map {
                    let alphaWeight = max(0.0, 1.0 - f2Blend - concentrationBlend)
                    return alphaWeight * alphaNormalized[$0]
                        + f2Blend * frequencyNormalized[$0]
                        + concentrationBlend * concentrationNormalized[$0]
                }
                let tickets = select(candidates: candidates, scores: blended, limit: recommendationCount)
                accumulators[variantIndex].add(tickets: tickets, target: target)
            }
        }

        let results = variants.indices.map { index in
            let variant = variants[index]
            let a = accumulators[index]
            let points = a.classes.enumerated().reduce(0) { total, item in
                let main = item.offset / 3
                let euro = item.offset % 3
                return total + main * main * item.element + euro * item.element
            }
            return AlphaFrequencyBlendResult.VariantResult(
                label: variant.0 == 0 && variant.1 == 0
                    ? "Alpha 7.5"
                    : "Alpha + F2 \(variant.0)% + Konzentration \(variant.1)%",
                frequencyPercent: variant.0,
                concentrationPercent: variant.1,
                classes: a.classes,
                totalPoints: points,
                mainHits: a.mainHits,
                euroHits: a.euroHits,
                higherHits: a.classes.enumerated().filter { $0.offset / 3 >= 2 }.reduce(0) { $0 + $1.element }
            )
        }

        print("===================================")
        print("🧪 ALPHA + F2-HAUPTZAHL-KONZENTRATION")
        print("Alpha-Profil: P\(String(format: "%02d", winner.id))")
        print("F2 wirkt nur auf die Hauptzahlen; Konzentration belohnt hoch gerankte Hauptzahlen")
        print("Qualitätswertung = Haupttreffer² + Eurotreffer")
        for result in results {
            print(String(format: "%-42@ | %4d Punkte | Ø %.3f | 2+ Haupt: %3d", result.label, result.totalPoints, Double(result.totalPoints) / 450.0, result.higherHits))
        }
        print("===================================")

        return AlphaFrequencyBlendResult(holdoutDraws: holdoutCount, alphaProfileID: winner.id, variants: results)
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
            return ranks[0] * 0.35
                + ranks[1] * 0.25
                + ranks[2] * 0.20
                + ranks[3] * 0.12
                + ranks[4] * 0.08
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
        mutating func add(tickets: [Ticket], target: EuroJackpotDraw) {
            for ticket in tickets {
                let main = Set(ticket.numbers).intersection(target.numbers).count
                let euro = Set(ticket.euroNumbers).intersection(target.euroNumbers).count
                classes[main * 3 + euro] += 1
                mainHits += main
                euroHits += euro
            }
        }
    }
}
