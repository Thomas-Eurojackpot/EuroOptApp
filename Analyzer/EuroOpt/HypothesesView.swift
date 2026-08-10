import SwiftUI

struct HypothesesView: View {

    @StateObject
    private var viewModel = OptimizerViewModel()

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
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Label("Mondphasentest starten", systemImage: "moon.stars")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isMoonPhaseRunning)

                            Text("Die Mondphase wird ausschließlich aus der Validation-Hälfte gewählt. Der Holdout bleibt unangetastet; anschließend erfolgt der gepaarte Zufallsbenchmark mit 50 Replikationen.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("🔒 Alpha 7.5") {
                        Text("Das eingefrorene Profil F 34 | P 0 | G/U 0 | H/N 33 | S 33 | A 0 wird durch diesen Test nicht verändert.")
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
