import SwiftUI

struct DashboardView2: View {

    @StateObject private var viewModel = OptimizerViewModel()
    @StateObject private var settingsViewModel = OptimizerSettingsViewModel()

    private let service = EuroJackpotService()
    private let importer = ImportService()

    var body: some View {

        let draws = service.loadDraws()
        let latestDraw = draws.last

        ScrollView {

            VStack(alignment: .leading, spacing: 14) {

                // =====================================================
                // HEADER
                // =====================================================

                VStack(alignment: .leading, spacing: 2) {

                    Text("🍀 EuroOpt")
                        .font(.title)
                        .bold()

                    Text("Version 1.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                }

                // =====================================================
                // LETZTE ZIEHUNG + DATENBANK
                // =====================================================

                HStack(alignment: .top, spacing: 12) {

                    GroupBox("📅 Letzte EuroJackpot-Ziehung") {

                        VStack(alignment: .leading, spacing: 5) {

                            if let draw = latestDraw {

                                compactNumberLine(
                                    prefix: "🎲",
                                    numbers: draw.numbers
                                )

                                compactNumberLine(
                                    prefix: "⭐",
                                    numbers: draw.euroNumbers
                                )

                                Text(
                                    draw.date.formatted(
                                        date: .long,
                                        time: .omitted
                                    )
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            } else {

                                Text("Keine Ziehungen vorhanden.")
                                    .foregroundStyle(.secondary)

                            }

                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )

                    }

                    GroupBox("📊 Datenbank") {

                        VStack(alignment: .leading, spacing: 5) {

                            Text("Ziehungen: \(draws.count)")
                                .font(.caption)

                            if let draw = latestDraw {

                                Text(
                                    "Letzte Aktualisierung: " +
                                    draw.date.formatted(
                                        date: .abbreviated,
                                        time: .omitted
                                    )
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            }

                            Button {

                                importer.refreshDraws { neueZiehungen in

                                    print(
                                        "Aktualisiert: \(neueZiehungen.count) Ziehungen"
                                    )

                                }

                            } label: {

                                Label(
                                    "Ziehungen aktualisieren",
                                    systemImage: "arrow.clockwise"
                                )
                                .font(.caption)

                            }
                            .buttonStyle(.bordered)

                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )

                    }

                }

                // =====================================================
                // HAUPTBEREICH
                // =====================================================

                HStack(alignment: .top, spacing: 12) {

                    // -------------------------------------------------
                    // EMPFEHLUNGEN
                    // -------------------------------------------------

                    GroupBox("🎯 Empfehlungen – Alpha 7.7") {

                        VStack(alignment: .leading, spacing: 8) {

                            HStack {

                                Text("Kandidaten:")
                                    .font(.caption)

                                Stepper(
                                    "\(settingsViewModel.candidateCount)",
                                    value: $settingsViewModel.candidateCount,
                                    in: 100...100_000,
                                    step: 100
                                )
                                .font(.caption)

                                Spacer()

                                Text("Empfehlungen:")
                                    .font(.caption)

                                Stepper(
                                    "\(settingsViewModel.recommendationCount)",
                                    value: $settingsViewModel.recommendationCount,
                                    in: 1...20
                                )
                                .font(.caption)

                            }

                            HStack {

                                Text(
                                    "Eurozahlen: Recency 50 / Top 2"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                Spacer()

                                Button {

                                    viewModel.calculateRecommendations(
                                        candidateCount:
                                            settingsViewModel.candidateCount,
                                        recommendationCount:
                                            settingsViewModel.recommendationCount
                                    )

                                } label: {

                                    if viewModel.isCalculating {

                                        ProgressView()
                                            .controlSize(.small)

                                    } else {

                                        Label(
                                            "Empfehlungen berechnen",
                                            systemImage: "sparkles"
                                        )
                                        .font(.caption)

                                    }

                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.isCalculating)

                            }

                            Divider()

                            if viewModel.reports.isEmpty {

                                Text(
                                    "Noch keine Empfehlungen berechnet."
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)

                            } else {

                                recommendationHeader()

                                ForEach(
                                    Array(
                                        viewModel.reports.enumerated()
                                    ),
                                    id: \.element.id
                                ) { index, report in

                                    recommendationRow(
                                        index: index,
                                        report: report
                                    )

                                    if index <
                                        viewModel.reports.count - 1 {

                                        Divider()

                                    }

                                }

                                ShareLink(
                                    item: viewModel.shareText,
                                    preview:
                                        SharePreview(
                                            "EuroOpt Empfehlungen"
                                        )
                                ) {

                                    Label(
                                        "Empfehlungen teilen",
                                        systemImage:
                                            "square.and.arrow.up"
                                    )
                                    .font(.caption)
                                    .frame(
                                        maxWidth: .infinity
                                    )

                                }
                                .buttonStyle(.bordered)

                            }

                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )

                    }
                    .frame(maxWidth: .infinity)

                    // -------------------------------------------------
                    // FORSCHUNG / DIAGNOSTIK
                    // -------------------------------------------------

                    GroupBox("🧪 Forschung / Diagnostik") {

                        VStack(alignment: .leading, spacing: 8) {

                            Text(
                                "Die ausführlichen Backtests, Holdouts und Diagnostiktests befinden sich separat im Bereich „Optimierer“."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            NavigationLink {

                                OptimizerView()

                            } label: {

                                Label(
                                    "Tests und Diagnostik öffnen",
                                    systemImage: "flask"
                                )
                                .font(.caption)
                                .frame(
                                    maxWidth: .infinity
                                )

                            }
                            .buttonStyle(.bordered)

                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )

                    }
                    .frame(
                        width: 250
                    )

                }

            }
            .padding()

        }
        .navigationTitle("Dashboard")

    }

    // =============================================================
    // KOMPAKTE ZAHLENZEILE
    // =============================================================

    private func compactNumberLine(
        prefix: String,
        numbers: [Int]
    ) -> some View {

        HStack(spacing: 5) {

            Text(prefix)

            ForEach(
                numbers,
                id: \.self
            ) { number in

                Text("\(number)")
                    .font(.caption)
                    .bold()

            }

        }

    }

    // =============================================================
    // EMPFEHLUNGS-KOPF
    // =============================================================

    private func recommendationHeader() -> some View {

        HStack(spacing: 8) {

            Text("")
                .frame(width: 24)

            Text("Hauptzahlen")
                .font(.caption)
                .bold()
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )

            Text("Eurozahlen")
                .font(.caption)
                .bold()
                .frame(width: 100)

            Text("EQI")
                .font(.caption)
                .bold()
                .frame(width: 45)

        }

    }

    // =============================================================
    // EMPFEHLUNGSZEILE
    // =============================================================

    private func recommendationRow(
        index: Int,
        report: OptimizerReport
    ) -> some View {

        HStack(spacing: 8) {

            Text(recommendationMedal(index))
                .frame(width: 24)

            Text(
                report.ticket.numbers
                    .map(String.init)
                    .joined(separator: " • ")
            )
            .font(.caption)
            .bold()
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )

            Text(
                report.ticket.euroNumbers
                    .map(String.init)
                    .joined(separator: " • ")
            )
            .font(.caption)
            .frame(width: 100)

            Text(
                "\(String(format: "%.0f", report.eqi.value)) %"
            )
            .font(.caption)
            .frame(width: 45)

        }
        .padding(.vertical, 2)

    }

    // =============================================================
    // MEDALS
    // =============================================================

    private func recommendationMedal(
        _ index: Int
    ) -> String {

        switch index {

        case 0:
            return "🥇"

        case 1:
            return "🥈"

        case 2:
            return "🥉"

        default:
            return "⭐"

        }

    }

}

#Preview {
    DashboardView2()
}
