//
//  BacktestView.swift
//  EuroOpt
//
//  Backtest
//

import SwiftUI

struct BacktestView: View {

    @StateObject
    private var viewModel = OptimizerViewModel()

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(alignment: .leading, spacing: 24) {

                    Text("🧪 EuroOpt Backtest")
                        .font(.largeTitle)
                        .bold()

                    Text("Historischer Test des Optimierers.")
                        .foregroundStyle(.secondary)

                    GroupBox("Status") {

                        VStack(alignment: .leading, spacing: 12) {

                            Text(viewModel.backtestStatus)

                            ProgressView(
                                value: viewModel.backtestProgress
                            )

                            Text(
                                "\(Int(viewModel.backtestProgress * 100)) %"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                    }

                    Button {
                        viewModel.runBacktest()
                    } label: {

                        if viewModel.isBacktestRunning {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label(
                                "Backtest starten",
                                systemImage: "flask"
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isBacktestRunning)

                    Button {
                        viewModel.runAlpha80VsRalfVsRandomBacktest()
                    } label: {

                        if viewModel.isBacktestRunning {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label(
                                "Alpha 8.0 vs Ralf vs Zufall",
                                systemImage: "chart.bar.xaxis"
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isBacktestRunning)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Backtest")
        }
    }
}

#Preview {
    BacktestView()
}

