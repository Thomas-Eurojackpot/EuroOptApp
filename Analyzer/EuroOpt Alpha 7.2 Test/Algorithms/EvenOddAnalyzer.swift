//
//  EvenOddAnalyzer.swift
//  EuroOpt
//
//  Alpha 7.4
//

import Foundation

final class EvenOddAnalyzer {

    func distribution(
        in context: AnalysisContext
    ) -> [String:Int] {

        var result: [String:Int] = [:]

        // Diese Verteilung wird künftig direkt aus dem AnalysisContext
        // aufgebaut. Bis dahin erzeugen wir sie einmal aus den Frequenzen.

        // Platzhalter für die Umstellung.
        // Damit bleibt das Projekt kompilierbar.

        result["2:3"] = 1
        result["3:2"] = 1

        return result

    }

}
