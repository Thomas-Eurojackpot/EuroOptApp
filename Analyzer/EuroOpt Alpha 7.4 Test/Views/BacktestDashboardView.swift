//
//  BacktestDashboardView.swift
//  EuroOpt
//
//  Alpha 6.6
//

import SwiftUI

struct BacktestDashboardView: View {

    let statistics: BacktestStatistics?
    let duration: Double

    var body: some View {

        GroupBox("📊 Backtest") {

            if let statistics {

                VStack(alignment: .leading, spacing: 14) {

                    dashboardRow(
                        title: "Getestete Ziehungen",
                        value: "\(statistics.totalTests)"
                    )

                    dashboardRow(
                        title: "Laufzeit",
                        value: String(format: "%.1f s", duration)
                    )

                    Divider()

                    dashboardRow(
                        title: "Ø Haupttreffer",
                        value: String(format: "%.2f", statistics.averageHits)
                    )

                    dashboardRow(
                        title: "Ø Eurotreffer",
                        value: String(format: "%.2f", statistics.averageEuroHits)
                    )

                    dashboardRow(
                        title: "Ø EQI",
                        value: String(format: "%.2f", statistics.averageEQI)
                    )

                    Divider()

                    dashboardRow(
                        title: "Beste Haupttreffer",
                        value: "\(statistics.bestHits)"
                    )

                    dashboardRow(
                        title: "Beste Eurotreffer",
                        value: "\(statistics.bestEuroHits)"
                    )

                    Divider()

                    Text("Trefferklassen")
                        .font(.headline)

                    dashboardRow(title: "5 Richtige", value: "\(statistics.hit5)")
                    dashboardRow(title: "4 Richtige", value: "\(statistics.hit4)")
                    dashboardRow(title: "3 Richtige", value: "\(statistics.hit3)")
                    dashboardRow(title: "2 Richtige", value: "\(statistics.hit2)")
                    dashboardRow(title: "1 Richtiger", value: "\(statistics.hit1)")
                    dashboardRow(title: "0 Richtige", value: "\(statistics.hit0)")

                    Divider()

                    Text("Eurotreffer")
                        .font(.headline)

                    dashboardRow(title: "2 Eurozahlen", value: "\(statistics.euroHit2)")
                    dashboardRow(title: "1 Eurozahl", value: "\(statistics.euroHit1)")
                    dashboardRow(title: "0 Eurozahlen", value: "\(statistics.euroHit0)")

                    Divider()

                    Text("Gewinnklassen")
                        .font(.headline)

                    ForEach(statistics.prizeClasses) { prize in

                        dashboardRow(
                            title: prize.prizeClass,
                            value: "\(prize.count)"
                        )

                    }

                }

            } else {

                ContentUnavailableView(
                    "Noch kein Backtest",
                    systemImage: "chart.bar.doc.horizontal",
                    description: Text("Starte einen Backtest.")
                )

            }

        }

    }

    @ViewBuilder
    private func dashboardRow(
        title: String,
        value: String
    ) -> some View {

        HStack {

            Text(title)

            Spacer()

            Text(value)
                .bold()

        }

    }

}

#Preview {

    BacktestDashboardView(
        statistics: nil,
        duration: 0
    )

}
