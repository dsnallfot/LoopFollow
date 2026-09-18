import UIKit

extension TreatmentsTableView {
    // MARK: - Data Loading
    
    func loadTreatments() {
        // For legacy/manual refresh, default to today
        loadInitialDaySections(anchoredAt: selectedDate)
    }

    /// Load treatments for a full calendar day (00:00–00:00) from NightscoutCache
    /// or fall back to a dynamic Nightscout fetch.
    func loadTreatments(for date: Date) {
        let cal = Calendar.current

        // Always use a full local calendar day for the selected date.
        // Any future-dated treatments that fall within this [start, end)
        // window (e.g. FPU-behandlingar senare ikväll) will be included.
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!

        // Visa alltid någon form av "loading" medan vi läser cachen.
        showRefreshIndicator()

        Task {
            // För alla datum (inkl. idag) försöker vi först läsa från NightscoutCache.
            let (sgvs, treatsJSON) = await NightscoutCache.loadWindow(from: start, to: end)
            let newTreatments = treatsJSON.compactMap { tjson in
                Treatment(dictionary: [
                    "_id":      tjson._id as AnyObject,
                    "eventType":tjson.eventType as AnyObject,
                    "enteredBy": tjson.enteredBy as AnyObject,
                    "created_at": ISO8601DateFormatter().string(from: tjson.created_at) as AnyObject,
                    "rate":     tjson.rate    as AnyObject,
                    "absolute": tjson.absolute as AnyObject,
                    "insulin":  tjson.insulin  as AnyObject,
                    "carbs":    tjson.carbs    as AnyObject,
                    "fat":      tjson.fat      as AnyObject,
                    "protein":  tjson.protein  as AnyObject,
                    "amount":   tjson.amount   as AnyObject,
                    "foodType": tjson.foodType as AnyObject,
                    "notes":    tjson.notes as AnyObject,
                    "glucose":  tjson.glucose as AnyObject,
                    "units":    tjson.units as AnyObject,
                    "duration": tjson.tempBasalDuration as AnyObject
                ])
            }

            // Bygg BG-punkter (mmol/L) från SGVs
            let newBGPoints: [BGPoint] = sgvs.map { sgv in
                BGPoint(
                    date: Date(timeIntervalSince1970: sgv.date),
                    mmol: Double(sgv.sgv) / 18.0182
                )
            }
            .sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                if !newTreatments.isEmpty {
                    // Cache-data fanns – visa hela kalenderdygnet 00:00–00:00 för valt datum.
                    self.treatments = newTreatments
                        .sorted { $0.timestamp > $1.timestamp }

                    // Spara BG-punkterna när vi faktiskt använder cache-datan
                    self.bgPoints = newBGPoints
                    self.storeBGPoints(newBGPoints, for: date)

                    self.tableView.reloadData()

                    // När vi tittar på "idag", auto-scrolla en gång till den senaste
                    // behandlingen som inte ligger i framtiden, så att realtidsinfo
                    // är i fokus men framtida/historiska rader finns kvar ovan/under.
                    let cal = Calendar.current
                    if cal.isDate(date, inSameDayAs: Date()),
                       !self.hasAutoScrolledToTodayLatest {

                        let now = Date()

                        // Basera auto-scroll på det aktuella filtret.
                        // Är segmentet "Alla" valt använder vi alla treatments,
                        // annars använder vi filteredTreatments.
                        let baseList: [Treatment]
                        if self.segmentedControl.selectedSegmentIndex == 0 {
                            baseList = self.treatments
                        } else {
                            baseList = self.filteredTreatments
                        }

                        if let rowIndex = baseList
                            .enumerated()
                            .filter({ $0.element.timestamp <= now })
                            .map({ $0.offset })
                            .first {

                            let indexPath = IndexPath(row: rowIndex, section: 0)
                            self.tableView.scrollToRow(at: indexPath, at: .top, animated: false)
                            self.hasAutoScrolledToTodayLatest = true
                        }
                    }

                    self.hideRefreshIndicator()
                } else {
                    // Ingen cache-data för den här dagen: fall back till live-fetch.
                    // Stäng av nuvarande indikator, fallback-metoden sköter sin egen show/hide.
                    self.hideRefreshIndicator()
                    self.fetchDynamicTreatments(for: date)
                }
            }
        }
    }

    /// Fallback: hämta de senaste N dagar (rolling window) för dagens datum direkt från Nightscout
    /// (används bara om cachen saknar data för idag).
    func fetchDynamicTreatments(for date: Date,
                                        completion: @escaping ([Treatment]) -> Void) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        iso.timeZone = .current

        let params: [String: String] = [
            "find[created_at][$gte]": iso.string(from: start),
            "find[created_at][$lte]": iso.string(from: end)
        ]

        NightscoutUtils.executeDynamicRequest(eventType: .treatments, parameters: params) { result in
            DispatchQueue.main.async {
                if case .success(let raw) = result,
                   let entries = raw as? [[String: AnyObject]] {
                    let fetched = entries
                        .compactMap { Treatment(dictionary: $0) }
                        .sorted { $0.timestamp > $1.timestamp }
                    completion(fetched)
                } else {
                    completion([])
                }
            }
        }
    }

    /// Fetch treatments dynamically for a specific calendar date (fallback if cache empty)
    func fetchDynamicTreatments(for date: Date) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        // Use system timezone so we cover the local day
        iso.timeZone = .current
        let params: [String: String] = [
            "find[created_at][$gte]": iso.string(from: start),
            "find[created_at][$lte]": iso.string(from: end)
        ]
        NightscoutUtils.executeDynamicRequest(eventType: .treatments, parameters: params) { result in
            DispatchQueue.main.async {
                if case .success(let raw) = result,
                   let entries = raw as? [[String: AnyObject]] {
                    let fetched = entries.compactMap { Treatment(dictionary: $0) }
                    self.treatments = fetched.sorted { $0.timestamp > $1.timestamp }
                }
                self.tableView.reloadData()
                // Ingen hideRefreshIndicator här – det sköts av loadTreatments(for:)
            }
        }
    }
}
