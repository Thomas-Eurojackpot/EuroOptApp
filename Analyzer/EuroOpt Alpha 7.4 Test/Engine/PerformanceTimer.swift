//
//  PerformanceTimer.swift
//  EuroOpt
//
//  Alpha 7.4
//

import Foundation

final class PerformanceTimer {

    private var startTimes: [String: CFAbsoluteTime] = [:]

    static let shared = PerformanceTimer()

    private init() {}

    func start(_ name: String) {

        startTimes[name] = CFAbsoluteTimeGetCurrent()

    }

    func stop(_ name: String) {

        guard let start = startTimes[name] else {
            return
        }

        let duration = CFAbsoluteTimeGetCurrent() - start

        print(String(
            format: "⏱ %-25@ %.3f s",
            name as NSString,
            duration
        ))

        startTimes.removeValue(forKey: name)

    }

}
