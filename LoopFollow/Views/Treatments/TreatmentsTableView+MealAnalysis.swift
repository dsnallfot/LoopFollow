import UIKit

// Event model is declared in MealAnalysis/Models/Event.swift
extension TreatmentsTableView {
    @objc func mealAnalysisButtonTapped() {
        let events = buildEventsArray()
        let cal = Calendar.current
        let start = cal.startOfDay(for: selectedDate)

        // Detect whether this controller is the root of its navigation stack.
        // If it is, we're in the modal presentation case.
        let isModalRoot = navigationController?.viewControllers.first === self

        if isModalRoot {
            // Modal quick-analysis: wrap in a UINavigationController and show "Klar".
            let analysisVC = MealAnalysisView(
                events: events,
                treatments: self.treatments,
                initialStart: start,
                modalWithTimestamp: true,
                modalTitleString: "Analys tid",
                showsDoneButton: true,
                preSelectedSegment: nil
            )
            analysisVC.delegate = self
            let navController = UINavigationController(rootViewController: analysisVC)
            navController.modalPresentationStyle = .formSheet
            present(navController, animated: true, completion: nil)
        } else {
            // Navigated from Settings: push onto the existing navigation stack,
            // hide the "Klar" button and rely on the back button instead.
            let analysisVC = MealAnalysisView(
                events: events,
                treatments: self.treatments,
                initialStart: start,
                modalWithTimestamp: true,
                modalTitleString: "Analys tid",
                showsDoneButton: false,
                preSelectedSegment: nil
            )
            analysisVC.delegate = self
            navigationController?.pushViewController(analysisVC, animated: true)
        }
    }

    func buildEventsArray() -> [Event] {
        // note: -> Event? in the closure so `return nil` is allowed
        var events: [Event] = treatments.compactMap { treatment -> Event? in
            switch treatment.eventType {
            case "SMB", "Bolus":
                // parse insulin value as before…
                let amt: Double?
                if let v = treatment.rawData["insulin"] as? Double {
                    amt = v
                } else if let str = treatment.amount?
                            .replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression),
                          let v = Double(str) {
                    amt = v
                } else {
                    amt = nil
                }
                guard let amount = amt else { return nil }
                return Event(
                    date: treatment.timestamp,
                    eventType: treatment.eventType,
                    amount: amount,
                    foodType: nil
                )

            case "Carb Correction":
                // parse carb grams
                let amt: Double?
                if let v = treatment.rawData["carbs"] as? Double {
                    amt = v
                } else if let str = treatment.amount?
                            .replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression),
                          let v = Double(str) {
                    amt = v
                } else {
                    amt = nil
                }
                guard let amount = amt else { return nil }

                // **here**: grab the foodType from rawData (or nil)
                let foodType = treatment.rawData["foodType"] as? String

                return Event(
                    date: treatment.timestamp,
                    eventType: treatment.eventType,
                    amount: amount,
                    foodType: foodType
                )

            case "BG Check":
                // Map BG Check to Event, converting units to mmol if needed
                if let glucose = treatment.rawData["glucose"] as? Double {
                    let units = treatment.rawData["units"] as? String ?? ""
                    let mmol = units.lowercased().contains("mmol") ? glucose : glucose / 18.0
                    return Event(
                        date: treatment.timestamp,
                        eventType: "BG Check",
                        amount: mmol,
                        foodType: nil
                    )
                }
                return nil
                
            case "Site Change":
                // Map Site changes to Event
                    return Event(
                        date: treatment.timestamp,
                        eventType: "Site Change",
                        amount: 0.0,
                        foodType: nil
                    )

            default:
                return nil
            }
        }
        // Temp Basal → forward the *rate* (U/h) so MealAnalysisView can compute pulses.
        let tempBasals = treatments
            .filter { $0.eventType == "Temp Basal" }
            .sorted { $0.timestamp < $1.timestamp }

        for basal in tempBasals {
            // Use `rate` first, fall back to `absolute`, default 0.0
            let rate = (basal.rawData["rate"] as? Double) ??
                       (basal.rawData["absolute"] as? Double) ?? 0.0

            events.append(
                Event(
                    date: basal.timestamp,
                    eventType: "Temp Basal",
                    amount: rate,          // pass the basal *rate* in U/h
                    foodType: nil
                )
            )
        }
        return events
    }
    
    // MARK: - MealAnalysisViewDelegate
    func mealAnalysisView(_ controller: MealAnalysisView,
                          didReturnWithStartDate startDate: Date,
                          didVisitEnteredBy: Bool) {
        let cal = Calendar.current
        let newDay = cal.startOfDay(for: startDate)
        let oldDay = cal.startOfDay(for: selectedDate)
        
        let dateChanged = !cal.isDate(oldDay, inSameDayAs: newDay)
        
        // 1) Alltid synka valt datum från MealAnalysisView → TreatmentsTableView
        selectedDate = newDay
        datePicker.setDate(selectedDate, animated: false)
        hasAutoScrolledToTodayLatest = false
        loadInitialDaySections(anchoredAt: selectedDate)
        
        // 2) Om användaren varit inne i EnteredByView, sätt filtret till "Manuell"
        if didVisitEnteredBy {
            let manualIndex = (0..<segmentedControl.numberOfSegments).first {
                segmentedControl.titleForSegment(at: $0) == "Manuell"
            } ?? 2
            
            segmentedControl.selectedSegmentIndex = manualIndex
            filterChanged()
        }
        
        // 3) Visa overlay endast om datumet faktiskt ändrades
        if dateChanged {
            showDateSyncOverlay(message: "Startdatumet från föregående vy följde med tillbaka till denna vy")
        }
    }
}
