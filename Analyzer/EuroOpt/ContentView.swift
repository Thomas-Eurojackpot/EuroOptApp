import SwiftUI

struct ContentView: View {

    var body: some View {

        NavigationSplitView {

            List {

                NavigationLink("Dashboard") {
                    DashboardView2()
                }

                NavigationLink("Statistik") {
                    StatisticsView()
                }

                NavigationLink("Optimierer") {
                    OptimizerView()
                }

                NavigationLink("Forschung / Diagnostik") {
                    ResearchDiagnosticsView()
                }

                NavigationLink("Einstellungen") {
                    SettingsView()
                }
            }
            .navigationTitle("EuroOpt")

        } detail: {

            DashboardView2()
        }
    }
}


// =============================================================
// FORSCHUNG / DIAGNOSTIK
// =============================================================

struct ResearchDiagnosticsView: View {

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 20) {

                VStack(alignment: .leading, spacing: 6) {

                    Text("🧪 Forschung / Diagnostik")
                        .font(.largeTitle)
                        .bold()

                    Text("Historische Tests und Vergleichsanalysen")
                        .foregroundStyle(.secondary)
                }


                GroupBox("📊 Strategievergleiche") {

                    VStack(spacing: 12) {

                        NavigationLink {
                            NineTipComparisonView()
                        } label: {

                            Label(
                                "9-Tipp-Vergleich",
                                systemImage: "chart.bar.xaxis"
                            )
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                        }
                        .buttonStyle(.bordered)


                        NavigationLink {
                            AlphaFrequencyBlendView()
                        } label: {

                            Label(
                                "Alpha + F2-Frequenz",
                                systemImage: "chart.line.uptrend.xyaxis"
                            )
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                        }
                        .buttonStyle(.bordered)

                    }
                }


                GroupBox("🧪 Historische Prüfung") {

                    VStack(spacing: 12) {

                        NavigationLink {
                            BacktestView()
                        } label: {

                            Label(
                                "Backtest",
                                systemImage: "flask"
                            )
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                        }
                        .buttonStyle(.bordered)

                    }
                }


                GroupBox("ℹ️ Hinweis") {

                    Text(
                        "Diese Funktionen dienen ausschließlich der historischen "
                        + "Analyse, dem Vergleich von Strategien und der Validierung. "
                        + "Sie verändern die aktuellen EuroOpt-Empfehlungen nicht."
                    )
                    .foregroundStyle(.secondary)
                }

            }
            .padding()
        }
        .navigationTitle("Forschung / Diagnostik")
    }
}


#Preview {
    ContentView()
}
