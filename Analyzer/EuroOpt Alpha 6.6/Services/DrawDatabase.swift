//
//  DrawDatabase.swift
//  EuroOpt
//
//  Alpha 6.0
//

import Foundation

final class DrawDatabase {

    // MARK: - Properties

    private let service = EuroJackpotService()

    // MARK: - Public

    func allDraws() -> [EuroJackpotDraw] {

        service.loadDraws()

    }

    var count: Int {

        allDraws().count

    }

    var latest: EuroJackpotDraw? {

        allDraws().last

    }

    // MARK: - Update

    func replaceDatabase(
        with data: Data
    ) throws {

        try data.write(
            to: service.databaseURL,
            options: .atomic
        )

    }

}
