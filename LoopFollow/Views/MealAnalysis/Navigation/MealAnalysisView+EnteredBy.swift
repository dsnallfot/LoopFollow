import UIKit

extension MealAnalysisView {
    @objc func enteredByButtonTapped() {
        // Markera att vi varit inne och fipplat med manuella behandlingar
        hasVisitedEnteredBy = true
        
        let enteredByVC = EnteredByView(startTime: startTime, endTime: endTime - 1) // Sätt ev 00:00 till 23:59:59 för att inte visa 2 dagar i EnteredByView
        enteredByVC.delegate = self
        let nav = UINavigationController(rootViewController: enteredByVC)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true, completion: nil)
    }

    /// Shifts the current time window an integral number of days while keeping its width.
    /// - Parameter days: Negative = back in time, Positive = forward.
}

// MARK: - EnteredByViewDelegate Conformance
extension MealAnalysisView: EnteredByViewDelegate {
    func enteredByView(_ controller: EnteredByView, didUpdateRange startDate: Date, endDate: Date) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        // Normalize to whole days
        let newStartDay = calendar.startOfDay(for: startDate)
        let newEndDay   = calendar.startOfDay(for: endDate)

        // Start is always 00:00 of chosen start day
        startTime = newStartDay

        // End is 00:00 next day, except if the chosen end day is today → end = now
        let newEnd: Date
        if calendar.isDate(newEndDay, inSameDayAs: todayStart) {
            newEnd = Date()
        } else {
            newEnd = calendar.date(byAdding: .day, value: 1, to: newEndDay)
                ?? newEndDay.addingTimeInterval(24 * 60 * 60)
        }
        endTime = newEnd

        // Reflect that we are in "Dag"-läge in UI
        let dagIndex = (0..<durationControl.numberOfSegments).first(where: {
            durationControl.titleForSegment(at: $0) == "Dag"
        }) ?? 6
        durationControl.selectedSegmentIndex = dagIndex
        lastDurationTitle = durationControl.titleForSegment(at: dagIndex)

        // Update pickers to match the new window
        startPicker.date = startTime
        endPicker.date   = endTime

        // Recalculate stats and graph
        updateTotals()
        updateBGLabels()
        
        // Visa overlay — vi vet att EnteredByView bara kallar delegaten när datum faktisk ändrats
        showDateSyncOverlay(message: "Datumvalen från föregående vy följde med tillbaka till denna vy")
    }
}
