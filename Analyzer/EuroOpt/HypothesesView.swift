import SwiftUI

struct HypothesesView: View {

    @StateObject
    private var viewModel = OptimizerViewModel()
    @StateObject
    private var moonConfirmation = MoonPhaseConfirmationViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("🌕 Hypothesen")
                        .font(.largeTitle)
                        .bold()

                    Text("Isolierte Tests für zusätzliche Hypothesen. Alpha 7.5 bleibt dabei unverändert.")
                        .foregroundStyle(.secondary)

                    GroupBox("🌙 Mondphasen") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(viewModel.moonPhaseStatus)

                            Button {
                                viewModel.runMoonPhaseTest()
                            } label: {
                                if viewModel.isMoonPhaseRunning {
                                    ProgressView().frame(maxWidth: .infinity)
                                } else {
                                    Label("Mondphasentest starten", systemImage: "moon.stars")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isMoonPhaseRunning || moonConfirmation.isRunning)

                            Text("Die erste Phase wurde ausschließlich aus der Validation gewählt. Dieser Test verändert Alpha 7.5 nicht.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("🌑 Unabhängige Bestätigung") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(moonConfirmation.status)

                            Text("Fixierte Phase: Neumond")
                                .font(.headline)

                            Button {
                                moonConfirmation.run()
                            } label: {
                                if moonConfirmation.isRunning {
                                    ProgressView().frame(maxWidth: .infinity)
                                } else {
                                    Label("Bestätigungstest starten", systemImage: "checkmark.seal")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(moonConfirmation.isRunning || viewModel.isMoonPhaseRunning)

                            Text("Es werden ausschließlich Ziehungen nach dem 07.08.2026 verwendet. Neumond wird nicht erneut ausgewählt oder optimiert. Sind noch keine neuen Ziehungen vorhanden, wartet der Test ohne Ergebnis.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("🔒 Alpha 7.5") {
                        Text("Das eingefrorene Profil F 34 | P 0 | G/U 0 | H/N 33 | S 33 | A 0 wird durch diese Tests nicht verändert.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Hypothesen")
        }
    }
}

#Preview {
    HypothesesView()
}
