import SwiftUI

struct DashboardView2: View {

    private let service = EuroJackpotService()
    private let importer = ImportService()

    var body: some View {

        let draws = service.loadDraws()
        let latestDraw = draws.last

        ScrollView {

            VStack(alignment: .leading, spacing: 20) {

                Text("🍀 EuroOpt")
                    .font(.largeTitle)
                    .bold()

                Text("Version 1.2")
                    .foregroundStyle(.secondary)

                Divider()

                GroupBox("📅 Letzte EuroJackpot-Ziehung") {

                    VStack(alignment: .leading, spacing: 8) {

                        if let draw = latestDraw {

                            Text("Zahlen: \(draw.numbers.map(String.init).joined(separator: ", "))")
                            Text("Eurozahlen: \(draw.euroNumbers.map(String.init).joined(separator: ", "))")
                            Text("Datum: \(draw.date.formatted(date: .long, time: .omitted))")

                        } else {

                            Text("Keine Ziehungen vorhanden.")

                        }

                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                }

                GroupBox("📊 Datenbank") {

                    VStack(alignment: .leading, spacing: 8) {

                        Text("Ziehungen: \(draws.count)")

                        Text("Quelle: draws.json")

                        if let draw = latestDraw {

                            Text("Letzte Aktualisierung: \(draw.date.formatted(date: .abbreviated, time: .omitted))")

                        } else {

                            Text("Letzte Aktualisierung: —")

                        }

                        Button("🔄 Ziehungen aktualisieren") {

                            importer.refreshDraws { neueZiehungen in

                                print("Aktualisiert: \(neueZiehungen.count) Ziehungen")

                            }

                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)

                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                }

                GroupBox("🧠 Optimierer") {

                    VStack(alignment: .leading) {

                        Text("Status: Bereit")
                        Text("Bewertete Systeme: 0")

                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                }

                GroupBox("🌕 Forschungsprojekt") {

                    VStack(alignment: .leading) {

                        Text("Mondphase: —")
                        Text("Hypothesen: 0")

                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                }

            }
            .padding()

        }

    }

}

#Preview {

    DashboardView2()

}
