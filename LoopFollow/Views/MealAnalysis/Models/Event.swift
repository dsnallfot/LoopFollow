import Foundation

/// Minimal representation of a treatment event we need
struct Event {
    let date: Date
    let eventType: String      // "SMB", "Bolus", "Carb Correction", etc.
    let amount: Double         // insulin units, carb grams, or blood glucose (mmol/L)
    let foodType: String?      // non-nil for Carb Corrections with fat/protein equivalents
}

