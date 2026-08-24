import SwiftUI

struct Alpha80VsRalfVsRandomBacktestView: View {
    @State private var running = false
    @State private var output = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alpha 8.0 vs Ralf vs Zufall")
                .font(.title2)
                .bold()

            Button(running ? "⏳ Test läuft…" : "▶️ Backtest starten") {
                running = true
                output = "Backtest gestartet … Ergebnis siehe Xcode-Konsole."
                let draws = EuroJackpotService().loadDraws()
                DispatchQueue.global(qos: .userInitiated).async {
                    Alpha80VsRalfVsRandomBacktestDiagnostic().run(
                        draws: draws,
                        candidateCount: AppSettings.backtestCandidateCount
                    )
                    DispatchQueue.main.async {
                        running = false
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(running)

            Text(output)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("8.0 vs Ralf vs Zufall")
    }
}

#Preview {
    Alpha80VsRalfVsRandomBacktestView()
}
