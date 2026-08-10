var actionSection: some View {

    VStack(spacing: 16) {

        Button {

            viewModel.calculateRecommendations(
                settings: settingsViewModel.settings
            )

        } label: {

            if viewModel.isCalculating {

                ProgressView()
                    .frame(maxWidth: .infinity)

            } else {

                Label(
                    "Empfehlungen berechnen",
                    systemImage: "sparkles"
                )
                .frame(maxWidth: .infinity)

            }

        }

        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isCalculating)

        // MARK: - Backtest

        Button {

            viewModel.runBacktest(
                settings: settingsViewModel.settings
            )

        } label: {

            Label(
                "🧪 Backtest starten",
                systemImage: "flask"
            )
            .frame(maxWidth: .infinity)

        }

        .buttonStyle(.bordered)

    }

}
