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

            Section("EQI-Gewichtung") {

                weightRow(
                    title: "Frequency",
                    value: $viewModel.frequencyWeight,
                    range: 0...100
                )

                weightRow(
                    title: "Pair",
                    value: $viewModel.pairWeight,
                    range: 0...100
                )

                weightRow(
                    title: "Even / Odd",
                    value: $viewModel.evenOddWeight,
                    range: 0...100
                )

                weightRow(
                    title: "High / Low",
                    value: $viewModel.highLowWeight,
                    range: 0...100
                )

                weightRow(
                    title: "Sum",
                    value: $viewModel.sumWeight,
                    range: 0...100
                )

                weightRow(
                    title: "Gap",
                    value: $viewModel.gapWeight,
                    range: 0...100
                )

            }

        }

        .navigationTitle("Optimizer")

    }

    @ViewBuilder
    private func weightRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {

        VStack(alignment: .leading, spacing: 6) {

            HStack {

                Text(title)

                Spacer()

                Text(String(format: "%.0f", value.wrappedValue))

                    .foregroundStyle(.secondary)

            }

            Slider(
                value: value,
                in: range,
                step: 1
            )

        }

        .padding(.vertical, 2)

    }

}

#Preview {

    OptimizerSettingsView(
        viewModel: OptimizerSettingsViewModel()
    )

}
