import Foundation
import Combine

@MainActor
final class MoonPhaseConfirmationViewModel: ObservableObject {

    @Published var isRunning = false
    @Published var status = "Noch kein unabhängiger Bestätigungstest gestartet"

    private let database = DrawDatabase()

    func run() {
        guard !isRunning else { return }

        let draws = database.allDraws()
        isRunning = true
        status = "Bestätigungstest prüft ausschließlich neue Ziehungen nach dem 07.08.2026..."

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            MoonPhaseEngine().runConfirmation(
                draws: draws,
                recommendationCount: AppSettings.recommendationCount
            )

            DispatchQueue.main.async {
                self.status = "Bestätigungstest beendet – Ergebnis im Konsolen-Output"
                self.isRunning = false
            }
        }
    }
}
