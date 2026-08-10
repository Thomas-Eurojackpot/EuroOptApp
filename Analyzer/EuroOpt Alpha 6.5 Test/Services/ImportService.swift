//
//  ImportService.swift
//  EuroOpt
//
//  Alpha 6.1
//

import Foundation

final class ImportService {

    private let localService = EuroJackpotService()
    private let updateManager = UpdateManager()

    func loadLocalDraws() -> [EuroJackpotDraw] {

        localService.loadDraws()

    }

    func refreshDraws(
        completion: @escaping ([EuroJackpotDraw]) -> Void
    ) {

        print("▶️ refreshDraws gestartet")

        updateManager.updateIfNeeded { updated in

            print("▶️ updateIfNeeded beendet")
            print("Update durchgeführt:", updated)

            DispatchQueue.main.async {

                let draws = self.localService.loadDraws()

                print("Ziehungen geladen:", draws.count)

                completion(draws)

            }

        }

    }

}
