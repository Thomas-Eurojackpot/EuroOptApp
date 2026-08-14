import Foundation

struct AlphaMainFrequencyBlendResult {
    struct VariantResult {
        let label: String
        let classes: [Int]
        let totalPoints: Int
        let higherHits: Int
    }

    let alphaProfileID: Int
    let variants: [VariantResult]

    static let labels: [String] = {
        var result: [String] = []
        for main in 0...5 {
            for euro in 0...2 {
                result.append("\(main)-\(euro)")
            }
        }
        return result
    }()
}

final class AlphaMainFrequencyBlendEngine {
    private let holdoutCount = 50
    private let warmup = WeightSweepCore.warmup
    private let recommendationCount = 9
    private let frequencyWeights = [0, 10, 20, 30]

    func run(draws: [EuroJackpotDraw]) -> AlphaMainFrequencyBlendResult? {
        guard draws.count > warmup + holdoutCount else {
            print("❌ Alpha-Hauptzahl-F2-Test: zu wenige Ziehungen")
            return nil
        }

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

        print("===================================")
        print("🧪 ALPHA 7.5 + F2-HAUPTZAHL-FREQUENZ")
        print("===================================")
        print("Alpha-Profil: P\(String(format: "%02d", winner.id))")
        print("F2-Einfluss: nur 5 Hauptzahlen")
        print("Eurozahlen: weiterhin ausschließlich Alpha")
        print("Varianten: Alpha 0 / +10 / +20 / +30 % F2")
        print("Holdout: letzte \(holdoutCount) Ziehungen")

        var accumulators = frequencyWeights.map { _ in HitAccumulator() }
        for index in holdoutStart..<draws.count {
            let training = Array(draws.prefix(index))
            let target = draws[index]
            let candidates = generator.generate(count: candidateCount, draws: training, goal: OptimizationGoal(), hillClimbingIterations: 0)
            let cache = ScoreCache(draws: training)
            let alphaEngine = ScoreEngine(cache: cache, goal: winner.goal)
            let alphaScores = candidates.map { alphaEngine.score(ticket: $0) }
            let mainFrequencyScores = mainFrequencyScores(for: candidates, draws: training)
            let alphaNormalized = normalize(alphaScores)
            let frequencyNormalized = normalize(mainFrequencyScores)

            for (variantIndex, percent) in frequencyWeights.enumerated() {
                let blend = Double(percent) / 100.0
                let blended = candidates.indices.map { (1.0 - blend) * alphaNormalized[$0] + blend * frequencyNormalized[$0] }
                let tickets = select(candidates: candidates, scores: blended, limit: recommendationCount)
                accumulators[variantIndex].add(tickets: tickets, target: target)
            }
        }

        let variants = frequencyWeights.indices.map { index in
            let percent = frequencyWeights[index]
            let a = accumulators[index]
            let points = a.classes.enumerated().reduce(0) { total, item in
                total + qualityPoints(main: item.offset / 3, euro: item.offset % 3) * item.element
            }
            return AlphaMainFrequencyBlendResult.VariantResult(
                label: percent == 0 ? "Alpha 7.5" : "Alpha + \(percent)% F2",
                classes: a.classes,
                totalPoints: points,
                higherHits: a.classes.enumerated().filter { $0.offset / 3 >= 2 }.reduce(0) { $0 + $1.element }
            )
        }

        print("Qualitätswertung = Haupttreffer² + Eurotreffer")
        for variant in variants {
            print(String(format: "%-18@ | %4d Punkte | Ø %.3f | 2+ Haupt: %3d", variant.label, variant.totalPoints, Double(variant.totalPoints) / 450.0, variant.higherHits))
        }
        print("===================================")

        return AlphaMainFrequencyBlendResult(alphaProfileID: winner.id, variants: variants)
    }

    private func mainFrequencyScores(for tickets: [Ticket], draws: [EuroJackpotDraw]) -> [Double] {
        let counts = mainCounts(draws: Array(draws.suffix(50)))
        let ranked = (1...50).sorted {
            if counts[$0, default: 0] == counts[$1, default: 0] { return $0 < $1 }
            return counts[$0, default: 0] > counts[$1, default: 0]
        }
        let denominator = Double(max(1, ranked.count - 1))
        let rank = Dictionary(uniqueKeysWithValues: ranked.enumerated().map { ($0.element, 1.0 - Double($0.offset) / denominator) })
        return tickets.map { ticket in
            ticket.numbers.reduce(0.0) { $0 + rank[$1, default: 0] } / 5.0
        }
    }

    private func mainCounts(draws: [EuroJackpotDraw]) -> [Int: Int] {
        var result = [Int: Int]()
        for draw in draws {
            for value in draw.numbers { result[value, default: 0] += 1 }
        }
        return result
    }

    private func normalize(_ values: [Double]) -> [Double] {
        guard let minValue = values.min(), let maxValue = values.max(), maxValue > minValue else { return values.map { _ in 0.5 } }
        return values.map { ($0 - minValue) / (maxValue - minValue) }
    }

    private func select(candidates: [Ticket], scores: [Double], limit: Int) -> [Ticket] {
        let ranked = candidates.indices.sorted { scores[$0] > scores[$1] }
        var result: [Ticket] = []
        for index in ranked {
            if result.allSatisfy({ WeightSweepCore.commonNumbers($0, candidates[index]) < 3 }) {
                result.append(candidates[index])
                if result.count == limit { break }
            }
        }
        return result
    }

    private func qualityPoints(main: Int, euro: Int) -> Int { main * main + euro }

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
        mutating func add(tickets: [Ticket], target: EuroJackpotDraw) {
            for ticket in tickets {
                let main = Set(ticket.numbers).intersection(target.numbers).count
                let euro = Set(ticket.euroNumbers).intersection(target.euroNumbers).count
                classes[main * 3 + euro] += 1
            }
        }
    }
}
