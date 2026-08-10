//
//  UpdateManager.swift
//  EuroOpt
//
//  Alpha 6.0
//

import Foundation

final class UpdateManager {

    // MARK: - Properties

    private let downloader = DownloadService()
    private let database = DrawDatabase()

    // MARK: - Public

    func updateIfNeeded(
        completion: @escaping (Bool) -> Void
    ) {

        print("▶️ updateIfNeeded gestartet")

        downloader.downloadVersion { result in

            switch result {

            case .success(let onlineVersion):

                print("✅ version.json geladen")
                print("Online Version:", onlineVersion.version)
                print("Online LastDraw:", onlineVersion.lastDraw)
                print("Online DrawCount:", onlineVersion.drawCount)

                let localDraws = self.database.allDraws()

                print("Lokale Ziehungen:", localDraws.count)

                guard let latestLocal = localDraws.last else {

                    print("Keine lokale Datenbank")

                    self.downloadDatabase(
                        completion: completion
                    )

                    return

                }

                print("Lokale letzte Ziehung:", latestLocal.date)

                // Hier lag der Fehler
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)

                guard let onlineDate = formatter.date(
                    from: onlineVersion.lastDraw
                ) else {

                    print("❌ Datum konnte nicht gelesen werden")

                    completion(false)
                    return

                }

                print("Online Datum:", onlineDate)

                if latestLocal.date < onlineDate {

                    print("⬇️ Download wird gestartet")

                    self.downloadDatabase(
                        completion: completion
                    )

                } else {

                    print("⛔ Kein Download nötig")

                    completion(false)

                }

            case .failure(let error):

                print("❌ Fehler beim Laden von version.json")
                print(error)

                completion(false)

            }

        }

    }

    // MARK: - Private

    private func downloadDatabase(
        completion: @escaping (Bool) -> Void
    ) {

        print("⬇️ downloadDatabase()")

        downloader.downloadDraws { result in

            switch result {

            case .success(let data):

                print("✅ draws.json geladen")
                print("Bytes:", data.count)

                do {

                    try self.database.replaceDatabase(
                        with: data
                    )

                    print("✅ Datenbank ersetzt")

                    completion(true)

                } catch {

                    print("❌ Fehler beim Speichern")
                    print(error)

                    completion(false)

                }

            case .failure(let error):

                print("❌ Fehler beim Download")
                print(error)

                completion(false)

            }

        }

    }

}
