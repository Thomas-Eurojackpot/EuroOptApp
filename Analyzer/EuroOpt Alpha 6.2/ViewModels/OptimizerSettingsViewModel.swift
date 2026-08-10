import Foundation
import Combine

final class OptimizerSettingsViewModel: ObservableObject {

    @Published var settings = OptimizerSettings()

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

}
