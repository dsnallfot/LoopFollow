import Foundation

extension BGCheckView {
    struct BGPoint {
        let date: Date
        let mmol: Double
    }

    struct CGMPoint {
        let date: Date
        let mmol: Double
    }

    struct LowTreatmentEntry {
        let date: Date
        let grams: Double
        let hasBGCheckNearby: Bool
        let cgmMmol: Double?
        let bgCheckMmol: Double?
    }

    enum Mode {
        case fingerstick
        case dextro
    }
}
