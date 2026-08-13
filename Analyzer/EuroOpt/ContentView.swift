import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink("Dashboard") { DashboardView2() }
                NavigationLink("Statistik") { StatisticsView() }
                NavigationLink("Optimierer") { OptimizerView() }
                NavigationLink("9-Tipp-Vergleich") { NineTipComparisonView() }
                NavigationLink("Alpha + F2-Frequenz") { AlphaFrequencyBlendView() }
                NavigationLink("Backtest") { BacktestView() }
                NavigationLink("Simulator") { SimulatorView() }
                NavigationLink("Hypothesen") { HypothesesView() }
                NavigationLink("Einstellungen") { SettingsView() }
            }
            .navigationTitle("EuroOpt")
        } detail: {
            DashboardView2()
        }
    }
}

#Preview { ContentView() }
