import Foundation

/// Tests whether the immediately preceding Eurojackpot draw
/// contains predictive information for the immediately following draw.
/// No F2 window, Alpha profile, weighting or selection is used.
final class F2FeatureAnalyzer {

    func run(draws: [EuroJackpotDraw]) {
        guard draws.count >= 2 else {
            print("❌ Vorherige-Ziehung-Test: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let observations = draws.count - 1

        var mainHits = 0
        var euroHits = 0
        var mainDistribution = Array(repeating: 0, count: 6)
        var euroDistribution = Array(repeating: 0, count: 3)
        var expectedEuroHits = 0.0

        let cutoff = ISO8601DateFormatter().date(from: "2022-03-25T00:00:00Z")!

        for index in 1..<draws.count {
            let previous = draws[index - 1]
            let target = draws[index]

            let previousMain = Set(previous.numbers)
            let targetMain = Set(target.numbers)
            let previousEuro = Set(previous.euroNumbers)
            let targetEuro = Set(target.euroNumbers)

            let main = previousMain.intersection(targetMain).count
            let euro = previousEuro.intersection(targetEuro).count

            mainHits += main
            euroHits += euro
            mainDistribution[main] += 1
            euroDistribution[euro] += 1

            let euroPoolSize = target.date >= cutoff ? 12.0 : 10.0
            expectedEuroHits += 2.0 * 2.0 / euroPoolSize
        }

        let meanMain = Double(mainHits) / Double(observations)
        let meanEuro = Double(euroHits) / Double(observations)
        let theoreticalMain = 0.5
        let theoreticalEuro = expectedEuroHits / Double(observations)

        print("")
        print("===================================")
        print("🔁 VORHERIGE ZIEHUNG → NÄCHSTE ZIEHUNG")
        print("===================================")
        print("Beobachtungen       : \(observations)")
        print("Bezug               : immer nur die unmittelbar vorherige Ziehung")
        print("Auswahl             : keine")
        print("F2                  : nicht verwendet")
        print("Alpha               : nicht verwendet")
        print("Holdout              : vollständige Historie, kausal zeitlich geordnet")
        print("")

        print("## HAUPTZAHLEN")
        print(String(format: "Treffer             : %d/%d", mainHits, observations))
        print(String(format: "Ø Treffer           : %.4f", meanMain))
        print(String(format: "Theoretische Basis  : %.4f", theoreticalMain))
        print(String(format: "Δ zur Zufallsbasis  : %+.4f", meanMain - theoreticalMain))
        print("")

        print("Trefferverteilung")
        for hits in 0...5 {
            print(String(format: "%d Treffer           : %d", hits, mainDistribution[hits]))
        }

        print("")
        print("## EUROZAHLEN")
        print(String(format: "Treffer             : %d/%d", euroHits, observations))
        print(String(format: "Ø Treffer           : %.4f", meanEuro))
        print(String(format: "Theoretische Basis  : %.4f", theoreticalEuro))
        print(String(format: "Δ zur Zufallsbasis  : %+.4f", meanEuro - theoreticalEuro))
        print("")

        print("Euro-Trefferverteilung")
        for hits in 0...2 {
            print(String(format: "%d Treffer           : %d", hits, euroDistribution[hits]))
        }

        print("")
        print("Interpretation:")
        print("Jede Ziehung wird ausschließlich mit der direkt vorherigen Ziehung verglichen.")
        print("Es gibt keine Optimierung und kein Auswahlgewicht.")
        print("Der Test prüft isoliert, ob eine unmittelbare Nachbarschaftswirkung erkennbar ist.")
        print(String(format: "⏱ Vorherige Ziehung → nächste Ziehung: %.2f Sekunden", Date().timeIntervalSince(start)))
    }
}
