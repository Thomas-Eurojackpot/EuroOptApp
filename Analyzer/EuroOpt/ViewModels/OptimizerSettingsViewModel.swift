import Foundation
import Combine

final class OptimizerSettingsViewModel: ObservableObject {

    @Published var settings = OptimizerSettings()

    // MARK: - Optimizer

    var candidateCount: Int {
        get {
            settings.candidateCount
        }
        set {
            settings.candidateCount = newValue
        }
    }

    var recommendationCount: Int {
        get {
            settings.recommendationCount
        }
        set {
            settings.recommendationCount = newValue
        }
    }

    // MARK: - Gewichte

    var frequencyWeight: Double {
        get { settings.frequencyWeight }
        set { settings.frequencyWeight = newValue }
    }

    var pairWeight: Double {
        get { settings.pairWeight }
        set { settings.pairWeight = newValue }
    }

    var evenOddWeight: Double {
        get { settings.evenOddWeight }
        set { settings.evenOddWeight = newValue }
    }

    var highLowWeight: Double {
        get { settings.highLowWeight }
        set { settings.highLowWeight = newValue }
    }

    var sumWeight: Double {
        get { settings.sumWeight }
        set { settings.sumWeight = newValue }
    }

    var gapWeight: Double {
        get { settings.gapWeight }
        set { settings.gapWeight = newValue }
    }

}
