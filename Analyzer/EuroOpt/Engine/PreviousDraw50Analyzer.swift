import Foundation

/// Tests the immediate previous-draw -> next-draw relationship on a fixed 50-draw OOS window.
final class PreviousDraw50Analyzer {

    private let warmup = 200
    private let observationCount = 50

    func run(draws: [EuroJackpotDraw]) {
        guard draws.count >= warmup + observationCount + 1 else {
            print("❌ Vorherige Ziehung 50-Test: zu wenige Ziehungen")
            return
        }

        let start = Date()
        let startIndex = draws.count - observationCount

        var mainHits = 0
        var euroHits = 0
        var mainDistribution = Array(repeating: 0, count: 6)
        var euroDistribution = Array(repeating: 0, count: 3)

        for index in startIndex..<draws.count {
            let previous = draws[index - 1]
            let target = draws[index]

            let previousMain = Set(previous.numbers)
            let previousEuro = Set(previous.euroNumbers)

            let main = target.numbers.filter { previousMain.contains($0) }.count
            let euro = target.euroNumbers.filter { previousEuro.contains($0) }.count

            mainHits += main
            euroHits += euro
            mainDistribution[main] += 1
            euroDistribution[euro] += 1
        }

        let mainRate = Double(mainHits) / Double(observationCount * 5)
        let euroRate = Double(euroHits) / Double(observationCount * 2)
        let mainBasis = 5.0 / 50.0
        let euroBasis = 2.0 / 12.0

        print("")
        print("===================================")
        print("🔎 VORHERIGE ZIEHUNG → NÄCHSTE | 50")
        print("===================================")
        print("Beobachtungen       : \(observationCount)")
        print("Bezug               : immer nur die unmittelbar vorherige Ziehung")
        print("Auswahl             : keine")
        print("F2                  : nicht verwendet")
        print("Alpha               : nicht verwendet")
        print("Holdout             : letzter 50-Ziehungen-Block, kausal")

        print("")
        print("## HAUPTZAHLEN")
        print("Treffer             : \(mainHits)/\(observationCount * 5)")
        print(String(format: "Ø Treffer           : %.4f", mainRate))
        print(String(format: "Theoretische Basis  : %.4f", mainBasis))
        print(String(format: "Δ zur Zufallsbasis  : %+.4f", mainRate - mainBasis))
        print("")
        print("Trefferverteilung")
        for hits in 0...5 {
            print(String(format: "%-20s: %d", "\(hits) Treffer", mainDistribution[hits]))
        }

        print("")
        print("## EUROZAHLEN")
        print("Treffer             : \(euroHits)/\(observationCount * 2)")
        print(String(format: "Ø Treffer           : %.4f", euroRate))
        print(String(format: "Theoretische Basis  : %.4f", euroBasis))
        print(String(format: "Δ zur Zufallsbasis  : %+.4f", euroRate - euroBasis))
        print("")
        print("Euro-Trefferverteilung")
        for hits in 0...2 {
            print(String(format: "%-20s: %d", "\(hits) Treffer", euroDistribution[hits]))
        }

        print("")
        print("Interpretation:")
        print("Jede der letzten 50 Ziehungen wird ausschließlich mit der direkt vorherigen Ziehung verglichen.")
        print("Der Test verwendet weder F2 noch Alpha und erzeugt kein Auswahlgewicht.")
        print("Er dient ausschließlich zur Reproduktion des unmittelbaren Nachbarschaftstests auf 50 Beobachtungen.")
        print(String(format: "⏱ Vorherige Ziehung → nächste Ziehung (50): %.2f Sekunden", Date().timeIntervalSince(start)))
    }
}
