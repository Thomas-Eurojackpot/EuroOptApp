import SwiftUI

struct AlphaMainFrequencyBlendView: View {
    @State private var running = false
    @State private var result: AlphaMainFrequencyBlendResult?
    @State private var status = "Noch kein Test gestartet"
    private let database = DrawDatabase()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("🧪 Alpha + F2-Hauptzahlen").font(.largeTitle).bold()
                Text("F2-Frequenz wird nur auf die 5 Hauptzahlen angewendet. Die Eurozahlen bleiben vollständig in der Alpha-Auswahl.")
                    .foregroundStyle(.secondary)
                Text("Varianten: Alpha 0 %, +10 %, +20 %, +30 % F2 · letzte 50 Holdout-Ziehungen")
                    .font(.footnote).foregroundStyle(.secondary)
                Button { run() } label: {
                    if running {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("Alpha + F2-Hauptzahlen-Test starten", systemImage: "chart.bar.xaxis")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(running)
                Text(status).font(.footnote).foregroundStyle(.secondary)
                if let result { table(result) }
            }
            .padding()
        }
        .navigationTitle("Alpha + F2-Hauptzahlen")
    }

    private func table(_ result: AlphaMainFrequencyBlendResult) -> some View {
        GroupBox("Qualitätswertung") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Alpha-Gewinner: P\(String(format: "%02d", result.alphaProfileID))").bold()
                ForEach(result.variants, id: \.label) { variant in
                    HStack {
                        Text(variant.label).frame(width: 150, alignment: .leading)
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
                    ForEach(result.variants, id: \.label) { Text($0.label).frame(maxWidth: .infinity, alignment: .trailing) }
                }.font(.caption).bold()
                ForEach(Array(AlphaMainFrequencyBlendResult.labels.enumerated()), id: \.offset) { index, label in
                    HStack {
                        Text(label).frame(width: 65, alignment: .leading)
                        ForEach(result.variants, id: \.label) { variant in
                            Text("\(variant.classes[index])").frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .font(.system(.body, design: .monospaced))
                }
            }
        }
    }

    private func run() {
        running = true
        result = nil
        status = "Test läuft..."
        let draws = database.allDraws()
        DispatchQueue.global(qos: .userInitiated).async {
            let r = AlphaMainFrequencyBlendEngine().run(draws: draws)
            DispatchQueue.main.async {
                result = r
                status = r == nil ? "Zu wenige Ziehungen." : "Test beendet."
                running = false
            }
        }
    }
}
