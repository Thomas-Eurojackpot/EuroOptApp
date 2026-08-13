import Foundation

final class F2MonteCarloWalkForwardAnalyzer {

    private let warmup = 200
    private let f2Window = 50
    private let topCount = 5
    private let blockSize = 40
    private let blockCount = 10

    func run(draws: [EuroJackpotDraw]) {
        guard draws.count >= warmup + blockSize * blockCount else {
            print("❌ F2 Monte-Carlo Walk-Forward: zu wenige Ziehungen")
            return
        }

        let start = Date()

        print("")
        print("===================================")
        print("🎲 F2/50 ↔ WALK-FORWARD OOS")
        print("===================================")
        print("Warm-up             : \(warmup)")
        print("F2                  : letzte \(f2Window) Trainingsziehungen")
        print("Auswahl             : Top \(topCount)")
        print("OOS-Blöcke          : \(blockCount)")
        print("Ziehungen je Block  : \(blockSize)")
        print("Auswahl             : keine")
        print("Produktionsprofil   : unverändert")
        print("Holdout             : vollständig out-of-sample")

        var f2Rates: [Double] = []
        var randomRates: [Double] = []
        var generator = SystemRandomNumberGenerator()

        for block in 0..<blockCount {
            let startIndex = warmup + block * blockSize
            let endIndex = startIndex + blockSize

            var f2Hits = 0
            var randomHits = 0

            for index in startIndex..<endIndex {
                let training = Array(draws[0..<index])
                let target = Set(draws[index].numbers)

                let f2Top = f2TopNumbers(from: training)

                for number in f2Top {
                    if target.contains(number) {
                        f2Hits += 1
                    }
                }

                let randomTop = Array(
                    (1...50).shuffled(using: &generator).prefix(topCount)
                )

                for number in randomTop {
                    if target.contains(number) {
                        randomHits += 1
                    }
                }
            }

            let observations = blockSize * topCount
            let f2Rate = Double(f2Hits) / Double(observations)
            let randomRate = Double(randomHits) / Double(observations)

            f2Rates.append(f2Rate)
            randomRates.append(randomRate)

            print(String(
                format: "Block %2d | F2 %.4f | Zufall %.4f | Δ %+.4f",
                block + 1,
                f2Rate,
                randomRate,
                f2Rate - randomRate
            ))
        }

        let meanF2 = f2Rates.reduce(0, +) / Double(f2Rates.count)
        let meanRandom = randomRates.reduce(0, +) / Double(randomRates.count)

        let positiveBlocks = zip(f2Rates, randomRates)
            .filter { $0.0 > $0.1 }
            .count

        print("")
        print("## ZUSAMMENFASSUNG")
        print(String(format: "Ø F2/50          : %.4f", meanF2))
        print(String(format: "Ø Zufall         : %.4f", meanRandom))
        print(String(format: "Ø Δ F2 − Zufall  : %+.4f", meanF2 - meanRandom))
        print("F2 besser        : \(positiveBlocks)/\(blockCount) Blöcke")

        print("")
        print("Interpretation:")
        print("Jeder Block wird ausschließlich mit davorliegenden Ziehungen trainiert.")
        print("Die folgenden Ziehungen bleiben vollständig out-of-sample.")
        print("Es wird kein Auswahlgewicht erzeugt und F2 bleibt unverändert.")

        print(String(
            format: "⏱ F2 Walk-Forward OOS: %.2f Sekunden",
            Date().timeIntervalSince(start)
        ))
    }

    private func f2TopNumbers(from draws: [EuroJackpotDraw]) -> [Int] {
        let source = Array(draws.suffix(f2Window))
        var counts = Array(repeating: 0, count: 51)

        for draw in source {
            for number in draw.numbers where number >= 1 && number <= 50 {
                counts[number] += 1
            }
        }

        return Array(
            (1...50)
                .sorted {
                    if counts[$0] != counts[$1] {
                        return counts[$0] > counts[$1]
                    }
                    return $0 < $1
                }
                .prefix(topCount)
        )
    }
}
