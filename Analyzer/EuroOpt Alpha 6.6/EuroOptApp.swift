//
//  EuroOptApp.swift
//  EuroOpt
//
//  Created by Thomas Menke on 02.08.26.
//

import SwiftUI

@main
struct EuroOptApp: App {

    init() {

        let updateManager = UpdateManager()

        updateManager.updateIfNeeded { updated in

            DispatchQueue.main.async {

                if updated {

                    print("✅ EuroOpt-Datenbank wurde aktualisiert.")

                } else {

                    print("ℹ️ Keine neuen Ziehungen verfügbar.")

                }

            }

        }

    }

    var body: some Scene {

        WindowGroup {

            ContentView()

        }

    }

}
