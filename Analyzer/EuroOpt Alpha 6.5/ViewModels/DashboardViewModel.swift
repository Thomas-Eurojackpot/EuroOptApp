import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {

    @Published var draws: [EuroJackpotDraw] = []

    private let importer = ImportService()

    init() {
        load()
    }

    func load() {
        draws = importer.loadLocalDraws()
    }

    func refresh() {

        importer.refreshDraws { neueZiehungen in

            self.draws = neueZiehungen

            print("Aktualisiert: \(neueZiehungen.count) Ziehungen")

        }

    }

    var latestDraw: EuroJackpotDraw? {
        draws.last
    }

}
