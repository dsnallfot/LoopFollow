import Foundation

// Compile with LoopFollow/Views/MealAnalysis/Models/BGEntry.swift.
@main
struct MealInsulinDifferenceTests {
    static func main() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(10_800)
        let entries = [BGEntry(date: start, mmol: 5), BGEntry(date: end, mmol: 8)]
        func estimate(_ points: [BGEntry], isf: Double? = 2,
                      stop: Date? = nil, now: Date? = nil) -> Double? {
            MealInsulinDifference.units(start: start, end: stop ?? end,
                                        entries: points, isf: isf, now: now ?? end)
        }
        precondition(estimate(entries) == 1.5)
        precondition(estimate([BGEntry(date: start, mmol: 8), BGEntry(date: end, mmol: 5)]) == -1.5)
        precondition(estimate([BGEntry(date: start, mmol: 5), BGEntry(date: end, mmol: 5)]) == 0)
        for invalidISF: Double? in [nil, 0, -2, .nan, .infinity] {
            precondition(estimate(entries, isf: invalidISF) == nil)
        }
        precondition(estimate([]) == nil)
        precondition(estimate([entries[0]]) == nil)
        precondition(estimate(entries, stop: start.addingTimeInterval(7200)) == nil)
        precondition(estimate(entries, now: end.addingTimeInterval(-1)) == nil)
        precondition(estimate([entries[0], BGEntry(date: end, mmol: 8, isGapFill: true)]) == nil)
        precondition(estimate([entries[0], BGEntry(date: end.addingTimeInterval(-301), mmol: 8)]) == nil)
        precondition(estimate([entries[0], BGEntry(date: end.addingTimeInterval(-300), mmol: 8)]) == 1.5)
        precondition(estimate([entries[0], BGEntry(date: end, mmol: .nan)]) == nil)
        precondition(estimate([entries[0], BGEntry(date: end, mmol: 0)]) == nil)
        precondition(MealInsulinDifference.formatted(1.5) == "+1.50 E")
        precondition(MealInsulinDifference.formatted(-1.5) == "-1.50 E")
        precondition(MealInsulinDifference.formatted(-0.001) == "0.00 E")
        precondition(MealInsulinDifference.formatted(0) == "0.00 E")
        precondition(MealInsulinDifference.theoreticalCarbRatio(carbs: 60, netInsulin: 2, difference: 1) == 20)
        precondition(MealInsulinDifference.theoreticalCarbRatio(carbs: 60, netInsulin: 2, difference: -1) == 60)
        precondition(MealInsulinDifference.theoreticalCarbRatio(carbs: 60, netInsulin: 2, difference: 0) == 30)
        precondition(MealInsulinDifference.theoreticalCarbRatio(carbs: 60, netInsulin: 2, difference: nil) == nil)
        precondition(MealInsulinDifference.theoreticalCarbRatio(carbs: 60, netInsulin: 2, difference: -2) == nil)
        precondition(MealInsulinDifference.theoreticalCarbRatio(carbs: 60, netInsulin: 2, difference: -3) == nil)
        precondition(MealInsulinDifference.theoreticalCarbRatio(carbs: 0, netInsulin: 2, difference: 1) == nil)
        precondition(MealInsulinDifference.theoreticalCarbRatio(carbs: .nan, netInsulin: 2, difference: 1) == nil)
        precondition(MealInsulinDifference.theoreticalCarbRatio(carbs: 60, netInsulin: .infinity, difference: 1) == nil)
        precondition(MealInsulinDifference.theoreticalCarbRatio(carbs: 60, netInsulin: 2, difference: .nan) == nil)
        print("Meal insulin difference and theoretical carb ratio tests passed")
    }
}
