import SwiftUI

struct NineTipComparisonView: View {
    @State private var running = false
    @State private var result: NineTipComparisonResult?
    @State private var status = "Noch kein Vergleich gestartet"
    private let database = DrawDatabase()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("🏆 9-Tipp-Vergleich").font(.largeTitle).bold()
                Text("Thomas (F2) ↔ Alpha 7.5 ↔ Ralf").font(.headline)
                Text("Letzte 50 Holdout-Ziehungen. F2: 1–5 bis 9–13. Alpha: echter WeightSweepCore. Ralf: 9 feste Reihen.").foregroundStyle(.secondary)
                Button {
                    run()
                } label: {
                    if running { ProgressView().frame(maxWidth: .infinity) }
                    else { Label("9-Tipp-Vergleich starten", systemImage: "chart.bar.xaxis").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(running)
                Text(status).font(.footnote).foregroundStyle(.secondary)
                if let result { table(result) }
            }
            .padding()
        }
        .navigationTitle("9-Tipp-Vergleich")
    }

    private func table(_ result: NineTipComparisonResult) -> some View {
        GroupBox("Trefferklassen") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Alpha-Gewinner: P\(String(format: "%02d", result.alphaProfileID))").bold()
                HStack { Text("Klasse").frame(width: 70, alignment: .leading); Text("Thomas").frame(maxWidth: .infinity, alignment: .trailing); Text("Alpha").frame(maxWidth: .infinity, alignment: .trailing); Text("Ralf").frame(maxWidth: .infinity, alignment: .trailing) }.font(.caption).bold()
                ForEach(Array(NineTipComparisonResult.classLabels.enumerated()), id: \.offset) { i, label in
                    HStack { Text(label).frame(width: 70, alignment: .leading); cell(result.players[0], i); cell(result.players[1], i); cell(result.players[2], i) }
                        .font(.system(.body, design: .monospaced))
                }
                Divider()
                Text("Prozent-Auswertung").font(.headline)
                ForEach(result.players, id: \.name) { p in
                    Text("\(p.name): Ø Haupt \(String(format: "%.3f", p.mainAverage)) | Ø Euro \(String(format: "%.3f", p.euroAverage))")
                        .font(.footnote)
                }
            }
        }
    }

    private func cell(_ player: NineTipComparisonResult.PlayerResult, _ index: Int) -> some View {
        VStack(alignment: .trailing) { Text("\(player.classes[index])"); Text(String(format: "%.1f%%", player.percentages[index])).font(.caption).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func run() {
        running = true; result = nil; status = "Vergleich läuft..."
        let draws = database.allDraws()
        DispatchQueue.global(qos: .userInitiated).async {
            let r = NineTipComparisonEngine().run(draws: draws)
            DispatchQueue.main.async { result = r; status = r == nil ? "Zu wenige Ziehungen." : "Vergleich beendet."; running = false }
        }
    }
}
