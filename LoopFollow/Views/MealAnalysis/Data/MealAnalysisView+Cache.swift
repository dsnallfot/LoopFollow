import UIKit

extension MealAnalysisView {
    // MARK: - Cache integration
    /// Extend `events` and `bgEntries` with any older data kept in NightscoutCache,
    /// then widen the startPicker’s lower bound.
    func loadCachedData() {
        Task.detached { [weak self] in
            guard let self = self else { return }
            // Ask for the full retention window (default 10 days)
            let cal = Calendar.current
            // Compute the start-of-day for the retention window
            let tempDate = cal.date(byAdding: .day,
                                    value: -NightscoutCache.retentionDays,
                                    to: Date())!
            let oldestWanted = cal.startOfDay(for: tempDate)

            LogManager.shared.log(category: .analysis, message: "Cache ▸ loadCachedData: requesting from \(oldestWanted) to now", isDebug: true)

            // Always load cached data up through the current moment
            let (sgvJSON, treatsJSON) = await NightscoutCache.loadWindow(
                from: oldestWanted,
                to: Date()
            )

            LogManager.shared.log(category: .analysis, message: "Cache ▸ raw sgvJSON.count = \(sgvJSON.count), treatsJSON.count = \(treatsJSON.count)", isDebug: true)

            // Convert SGVs → BGEntry, convert mg/dL → mmol/L (18.0182)
            let extraBG = sgvJSON.map {
                BGEntry(
                    date: Date(timeIntervalSince1970: $0.date),
                    mmol: Double($0.sgv) / 18.0182  // mg/dL → mmol/L
                )
            }

            // Convert Treatments → Event (subset of buildEventsArray logic)
            let extraEvents: [Event] = treatsJSON.compactMap { t in
                switch t.eventType {
                case "SMB":
                    guard let amt = t.insulin else { return nil }
                    return Event(date: t.created_at, eventType: "SMB", amount: amt, foodType: nil)
                case "Bolus", "Correction Bolus":
                    guard let amt = t.insulin else { return nil }
                    return Event(date: t.created_at, eventType: "Bolus", amount: amt, foodType: nil)
                case "Carb Correction":
                    guard let grams = t.carbs else { return nil }
                    return Event(date: t.created_at, eventType: "Carb Correction",
                                 amount: grams, foodType: t.foodType)
                case "Temp Basal":
                    let rate = t.rate ?? t.absolute ?? 0.0
                    return Event(date: t.created_at, eventType: "Temp Basal", amount: rate, foodType: nil)
                case "BG Check":
                    guard let glucose = t.glucose else { return nil }
                    let mmol: Double
                    if let units = t.units?.lowercased(), units.contains("mmol") {
                        mmol = glucose
                    } else {
                        mmol = glucose / 18.0
                    }
                    return Event(date: t.created_at, eventType: "BG Check", amount: mmol, foodType: nil)
                default:
                    return nil
                }
            }

            // Merge without duplicates (by exact timestamp + type)
            DispatchQueue.main.async {
                LogManager.shared.log(category: .analysis, message: "Cache ▸ existing bgEntries.count = \(self.bgEntries.count)", isDebug: true)
                LogManager.shared.log(category: .analysis, message: "Cache ▸ extraBG.count = \(extraBG.count)", isDebug: true)
                // BG merge
                let merged = self.normalizedMergedBG(existing: self.bgEntries, new: extraBG)
                self.bgEntries = merged
                LogManager.shared.log(category: .analysis, message: "Cache ▸ merged bgEntries.count = \(self.bgEntries.count)", isDebug: true)

                // Event merge
                let existingKeys = Set(self.events.map { "\($0.date.timeIntervalSince1970)|\($0.eventType)" })
                self.events += extraEvents.filter {
                    !existingKeys.contains("\($0.date.timeIntervalSince1970)|\($0.eventType)")
                }
                self.events.sort { $0.date < $1.date }
                LogManager.shared.log(category: .analysis, message: "Cache ▸ extraEvents.count = \(extraEvents.count), merged events.count = \(self.events.count)", isDebug: true)

                // Normalize BG Check events to mmol/L (guard against mg/dL sneaking in)
                // Heuristic: reasonable mmol range is ~2–25. If value > 40, assume mg/dL.
                for idx in 0..<self.events.count {
                    var e = self.events[idx]
                    if e.eventType == "BG Check", e.amount > 40 {
                        let converted = e.amount / 18.0182
                        self.events[idx] = Event(
                            date: e.date,
                            eventType: e.eventType,
                            amount: converted,
                            foodType: e.foodType
                        )
                        LogManager.shared.log(
                            category: .temporaryDebug,
                            message: "[MealAnalysis][Graphs] Normalized BG Check from \(e.amount) mg/dL to \(converted) mmol/L at \(e.date)",
                            isDebug: true
                        )
                    }
                }

                // Broaden the picker’s lower bound to the earliest entry we now have
                if let earliest = (self.events.map { $0.date } + self.bgEntries.map { $0.date }).min() {
                    self.startPicker.minimumDate = earliest
                    self.endPicker.minimumDate = earliest
                }

                // Refresh totals & charts if the user is looking at an older window
                self.updateTotals()
                self.updateBGLabels()
            }
        }
    }
}
