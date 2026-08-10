import Foundation

struct EQI {

    let value: Double

    var rating: String {

        switch value {

        case 90...100:
            return "★★★★★ Exzellent"

        case 80..<90:
            return "★★★★☆ Sehr gut"

        case 70..<80:
            return "★★★☆☆ Gut"

        case 60..<70:
            return "★★☆☆☆ Durchschnitt"

        default:
            return "★☆☆☆☆ Niedrig"

        }

    }

    var colorName: String {

        switch value {

        case 90...100:
            return "green"

        case 80..<90:
            return "mint"

        case 70..<80:
            return "yellow"

        case 60..<70:
            return "orange"

        default:
            return "red"

        }

    }

}
