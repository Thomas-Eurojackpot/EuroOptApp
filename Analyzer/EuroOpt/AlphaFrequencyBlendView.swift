import SwiftUI

struct AlphaFrequencyBlendView: View {
    @State private var running = false
    @State private var result: AlphaFrequencyConfirmationResult?
    @State private var status = "Noch kein Test gestartet"
    private let database = DrawDatabase()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("🧪 Alpha + F2-Bestätigung").font(.largeTitle).bold()
                Text("Alpha 7.5 vs. Alpha + 5% F2 + 30% Konzentration – drei getrennte 50er-Holdout-Fenster.").foregroundStyle(.secondary)
                Text("Jedes Fenster wählt sein Alpha-Profil nur aus der vorher verfügbaren Historie.").font(.footnote).foregroundStyle(.secondary)
                Button { run() } label: {
                    if running { ProgressView().frame(maxWidth: .infinity) }
                    else { Label("Bestätigungstest starten", systemImage: "chart.bar.xaxis").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(running)
                Text(status).font(.footnote).foregroundStyle(.secondary)
                if let result { table(result) }
            }
            .padding()
        }
        .navigationTitle("Alpha + F2-Bestätigung")
    }

    private func table(_ result: AlphaFrequencyConfirmationResult) -> some View {
        GroupBox("Mehrfenster-Bestätigung") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Fenstergebnisse").font(.headline)
                HStack {
                    Text("Fenster").frame(width: 65, alignment: .leading)
                    Text("Profil").frame(width: 65, alignment: .leading)
                    Text("Alpha").frame(width: 95, alignment: .trailing)
                    Text("F2 + Kon.").frame(width: 105, alignment: .trailing)
                    Text("2+ A").frame(width: 65, alignment: .trailing)
                    Text("2+ F2").frame(maxWidth: .infinity, alignment: .trailing)
                }.font(.caption).bold()
                ForEach(result.windows, id: \.windowNumber) { window in
                    HStack {
                        Text("\(window.windowNumber)").frame(width: 65, alignment: .leading)
                        Text("P\(String(format: "%02d", window.alphaProfileID))").frame(width: 65, alignment: .leading)
                        Text("\(window.alphaPoints) P").frame(width: 95, alignment: .trailing)
                        Text("\(window.blendPoints) P").frame(width: 105, alignment: .trailing)
                        Text("\(window.alphaHigherHits)").frame(width: 65, alignment: .trailing)
                        Text("\(window.blendHigherHits)").frame(maxWidth: .infinity, alignment: .trailing)
                    }.font(.system(.body, design: .monospaced))
                }
                Divider()
                Text("Gesamtwertung").font(.headline)
                ForEach(result.variants, id: \.label) { variant in
                    HStack {
                        Text(variant.label).frame(width: 230, alignment: .leading)
                        Text("\(variant.totalPoints) P").frame(width: 80, alignment: .trailing)
                        Text(String(format: "Ø %.3f", Double(variant.totalPoints) / Double(result.holdoutDraws * 9))).frame(width: 85, alignment: .trailing)
                        Text("2+ Haupt: \(variant.higherHits)").frame(maxWidth: .infinity, alignment: .trailing)
                    }.font(.system(.body, design: .monospaced))
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
        running = true; result = nil; status = "Mehrfenster-Test läuft..."
        let draws = database.allDraws()
        DispatchQueue.global(qos: .userInitiated).async {
            let r = AlphaFrequencyBlendEngine().run(draws: draws)
            DispatchQueue.main.async { result = r; status = r == nil ? "Zu wenige Ziehungen." : "Bestätigungstest beendet."; running = false }
        }
    }
}
