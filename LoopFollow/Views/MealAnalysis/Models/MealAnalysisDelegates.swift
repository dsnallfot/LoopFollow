import Foundation

// MARK: - EnteredByViewDelegate Protocol
protocol EnteredByViewDelegate: AnyObject {
    func enteredByView(_ controller: EnteredByView, didUpdateRange startDate: Date, endDate: Date)
}

// MARK: - MealAnalysisViewDelegate Protocol
protocol MealAnalysisViewDelegate: AnyObject {
    func mealAnalysisView(_ controller: MealAnalysisView,
                          didReturnWithStartDate startDate: Date,
                          didVisitEnteredBy: Bool)
}

