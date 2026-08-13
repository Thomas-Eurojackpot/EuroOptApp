import SwiftUI

struct AlphaFrequencyBlendView: View {
    @State private var running = false
    @State private var result: AlphaFrequencyBlendResult?
    @State private var status = "Noch kein Test gestartet"
    private let database = DrawDatabase()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("🧪 Alpha + F2-Frequenz").font(.largeTitle).bold()
                Text("Alpha 7.5 bleibt unverändert – nur die Kandidatenauswahl wird mit F2-Frequenz gemischt.").foregroundStyle(.secondary)
                Text("Varianten: Alpha 0 %, +10 %, +20 %, +30 % F2 · letzte 50 Holdout-Ziehungen").font(.footnote).foregroundStyle(.secondary)
                Button { run() } label: {
                    if running { ProgressView().frame(maxWidth: .infinity) }
                    else { Label("Alpha + F2-Test starten", systemImage: "chart.bar.xaxis").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(running)
                Text(status).font(.footnote).foregroundStyle(.secondary)
                if let result { table(result) }
            }
            .padding()
        }
        .navigationTitle("Alpha + F2-Frequenz")
    }

    private func table(_ result: AlphaFrequencyBlendResult) -> some View {
        GroupBox("Qualitätswertung") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Alpha-Gewinner: P\(String(format: "%02d", result.alphaProfileID))").bold()
                ForEach(result.variants, id: \.label) { variant in
                    HStack {
                        Text(variant.label).frame(width: 130, alignment: .leading)
                        Text("\(variant.totalPoints) P").frame(width: 70, alignment: .trailing)
                        Text(String(format: "Ø %.3f", Double(variant.totalPoints) / 450.0)).frame(width: 75, alignment: .trailing)
                        Text("2+ Haupt: \(variant.higherHits)").frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.system(.body, design: .monospaced))
                }
                Divider()
                Text("Trefferklassen").font(.headline)
                HStack {
                    Text("Klasse").frame(width: 65, alignment: .leading)
                    ForEach(result.variants, id: \.label) { variant in Text(variant.label).frame(maxWidth: .infinity, alignment: .trailing) }
                }.font(.caption).bold()
                ForEach(Array(result.variants.first?.classes.indices ?? 0..<0), id: \.self) { index in
                    HStack {
                        Text("\(index / 3)-\(index % 3)").frame(width: 65, alignment: .leading)
                        ForEach(result.variants, id: \.label) { variant in Text("\(variant.classes[index])").frame(maxWidth: .infinity, alignment: .trailing) }
                    }.font(.system(.body, design: .monospaced))
                }
            }
        }
    }

    private func run() {
        running = true; result = nil; status = "Test läuft..."
        let draws = database.allDraws()
        DispatchQueue.global(qos: .userInitiated).async {
            let r = AlphaFrequencyBlendEngine().run(draws: draws)
            DispatchQueue.main.async { result = r; status = r == nil ? "Zu wenige Ziehungen." : "Test beendet."; running = false }
        }
    }
}
