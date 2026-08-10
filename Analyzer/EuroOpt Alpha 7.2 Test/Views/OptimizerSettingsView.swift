import SwiftUI

struct OptimizerSettingsView: View {

    @ObservedObject var viewModel: OptimizerSettingsViewModel

    var body: some View {

        Form {

            Section("Kandidaten") {

                Picker(
                    "Anzahl der Kandidaten",
                    selection: $viewModel.candidateCount
                ) {

                    Text("1.000")
                        .tag(1000)

                    Text("10.000")
                        .tag(10000)

                    Text("100.000")
                        .tag(100000)

                }

                .pickerStyle(.menu)

            }

            Section("Empfehlungen") {

                Stepper(
                    value: $viewModel.recommendationCount,
                    in: 1...20
                ) {

                    Text("\(viewModel.recommendationCount) Empfehlungen")

                }

            }

            Section("Strategie") {

                Text("🚧 Kommt in einer späteren Version")
                    .foregroundStyle(.secondary)

            }

        }

        .navigationTitle("Optimizer")

    }

}

#Preview {

    OptimizerSettingsView(
        viewModel: OptimizerSettingsViewModel()
    )

}
