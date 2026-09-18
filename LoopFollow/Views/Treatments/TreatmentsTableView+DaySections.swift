import UIKit

extension TreatmentsTableView {
    var filteredDaySections: [TreatmentDaySection] {
        daySections.compactMap { section in
            let filtered: [Treatment]

            switch segmentedControl.selectedSegmentIndex {
            case 1: // Auto
                filtered = section.treatments.filter { autoTypes.contains($0.eventType) }

            case 2: // Manual
                filtered = section.treatments.filter { treatment in
                    if treatment.eventType == "Carb Correction" {
                        if let foodType = treatment.rawData["foodType"] as? String, !foodType.isEmpty {
                            return true
                        } else {
                            return false
                        }
                    } else {
                        return manualTypes.contains(treatment.eventType)
                    }
                }

            case 3: // Övrigt
                filtered = section.treatments.filter {
                    !autoTypes.contains($0.eventType) && !manualTypes.contains($0.eventType)
                }

            default: // Alla
                filtered = section.treatments
            }

            guard !filtered.isEmpty else { return nil }
            return TreatmentDaySection(date: section.date, treatments: filtered)
        }
    }

    var filteredTreatments: [Treatment] {
        filteredDaySections.flatMap { $0.treatments }
    }
    func treatment(for indexPath: IndexPath) -> Treatment {
        filteredDaySections[indexPath.section].treatments[indexPath.row]
    }

    func rebuildTreatmentsFlatCache() {
        treatments = daySections
            .flatMap { $0.treatments }
            .sorted { $0.timestamp > $1.timestamp }
    }

    func filteredSectionIndex(for date: Date) -> Int? {
        let cal = Calendar.current
        return filteredDaySections.firstIndex { cal.isDate($0.date, inSameDayAs: date) }
    }

    func daySectionIndex(for date: Date) -> Int? {
        let cal = Calendar.current
        return daySections.firstIndex { cal.isDate($0.date, inSameDayAs: date) }
    }

    private func canLoadOlderDay(from date: Date) -> Bool {
        guard let minimumDate = datePicker.minimumDate else { return true }
        let cal = Calendar.current
        return cal.startOfDay(for: date) >= cal.startOfDay(for: minimumDate)
    }

    func dayTitle(for date: Date) -> String {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "EEEE d MMM"

        if cal.isDateInToday(date) {
            return "Idag • " + formatter.string(from: date).capitalized
        } else if cal.isDateInYesterday(date) {
            return "Igår • " + formatter.string(from: date).capitalized
        } else {
            return formatter.string(from: date).capitalized
        }
    }

    private func mergeOrAppendDaySection(_ newSection: TreatmentDaySection) {
        let cal = Calendar.current

        if let existingIndex = daySections.firstIndex(where: { cal.isDate($0.date, inSameDayAs: newSection.date) }) {
            daySections[existingIndex] = newSection
        } else {
            daySections.append(newSection)
            daySections.sort { $0.date > $1.date }
        }

        oldestLoadedDay = daySections.map(\.date).min()
        rebuildTreatmentsFlatCache()
    }
    
    func loadInitialDaySections(anchoredAt date: Date) {
        let cal = Calendar.current
        let anchorDay = cal.startOfDay(for: date)

        daySections.removeAll()
        treatments.removeAll()
        oldestLoadedDay = nil
        bgPoints = []

        showRefreshIndicator()

        let group = DispatchGroup()
        var loadedSections: [TreatmentDaySection] = []
        var anchorBGPoints: [BGPoint] = []

        for offset in 0..<initialLoadedDayCount {
            guard let day = cal.date(byAdding: .day, value: -offset, to: anchorDay),
                  canLoadOlderDay(from: day) else { continue }

            group.enter()
            loadDaySection(for: day) { section, points in
                if let section {
                    loadedSections.append(section)
                }
                if cal.isDate(day, inSameDayAs: anchorDay) {
                    anchorBGPoints = points
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.daySections = loadedSections.sorted { $0.date > $1.date }
            self.oldestLoadedDay = self.daySections.map(\.date).min()
            self.rebuildTreatmentsFlatCache()
            self.bgPoints = anchorBGPoints
            self.tableView.reloadData()
            self.updateDuplicateIndicator()

            if cal.isDate(anchorDay, inSameDayAs: Date()) && !self.hasAutoScrolledToTodayLatest {
                self.scrollToLatestNonFutureTreatmentForTodayIfNeeded()
            } else if let sectionIndex = self.filteredSectionIndex(for: anchorDay),
                      !self.filteredDaySections[sectionIndex].treatments.isEmpty {
                self.tableView.scrollToRow(
                    at: IndexPath(row: 0, section: sectionIndex),
                    at: .top,
                    animated: false
                )
            }

            self.hideRefreshIndicator()
            self.syncSelectedDateFromVisibleSection()
            self.maybeLoadOlderDaysIfNeeded()
        }
    }
    
    private func loadSingleDaySection(for date: Date, reloadTable: Bool) {
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)

        loadDaySection(for: day) { section, points in
            DispatchQueue.main.async {
                if let section {
                    self.mergeOrAppendDaySection(section)
                }

                if cal.isDate(day, inSameDayAs: self.selectedDate) {
                    self.bgPoints = points
                }

                if reloadTable {
                    self.tableView.reloadData()
                    self.updateDuplicateIndicator()
                    self.syncSelectedDateFromVisibleSection()
                    self.maybeLoadOlderDaysIfNeeded()
                    self.hideRefreshIndicator()
                }
            }
        }
    }
    
    private func loadDaySection(for date: Date,
                                completion: @escaping (TreatmentDaySection?, [BGPoint]) -> Void) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!

        Task {
            let (sgvs, treatsJSON) = await NightscoutCache.loadWindow(from: start, to: end)

            let cachedTreatments = treatsJSON.compactMap { tjson in
                Treatment(dictionary: [
                    "_id": tjson._id as AnyObject,
                    "eventType": tjson.eventType as AnyObject,
                    "enteredBy": tjson.enteredBy as AnyObject,
                    "created_at": ISO8601DateFormatter().string(from: tjson.created_at) as AnyObject,
                    "rate": tjson.rate as AnyObject,
                    "absolute": tjson.absolute as AnyObject,
                    "insulin": tjson.insulin as AnyObject,
                    "carbs": tjson.carbs as AnyObject,
                    "fat": tjson.fat as AnyObject,
                    "protein": tjson.protein as AnyObject,
                    "amount": tjson.amount as AnyObject,
                    "foodType": tjson.foodType as AnyObject,
                    "notes": tjson.notes as AnyObject,
                    "glucose": tjson.glucose as AnyObject,
                    "units": tjson.units as AnyObject,
                    "duration": tjson.tempBasalDuration as AnyObject
                ])
            }
            .sorted { $0.timestamp > $1.timestamp }

            let points: [BGPoint] = sgvs.map { sgv in
                BGPoint(
                    date: Date(timeIntervalSince1970: sgv.date),
                    mmol: Double(sgv.sgv) / 18.0182
                )
            }
            .sorted { $0.date < $1.date }
            
            self.storeBGPoints(points, for: start)

            if !cachedTreatments.isEmpty {
                completion(TreatmentDaySection(date: start, treatments: cachedTreatments), points)
            } else {
                fetchDynamicTreatments(for: start) { fetched in
                    completion(
                        fetched.isEmpty ? nil : TreatmentDaySection(date: start, treatments: fetched),
                        points
                    )
                }
            }
        }
    }
    
    private func loadNextOlderDaySectionIfNeeded() {
        guard !isLoadingOlderDays,
              let oldestLoadedDay else { return }

        let cal = Calendar.current
        guard let nextDay = cal.date(byAdding: .day, value: -1, to: oldestLoadedDay),
              canLoadOlderDay(from: nextDay) else { return }

        isLoadingOlderDays = true

        loadDaySection(for: nextDay) { section, points in
            DispatchQueue.main.async {
                defer { self.isLoadingOlderDays = false }

                self.storeBGPoints(points, for: nextDay)

                if let section {
                    self.mergeOrAppendDaySection(section)
                    self.tableView.reloadData()
                    self.updateDuplicateIndicator()
                    self.syncSelectedDateFromVisibleSection()
                    self.maybeLoadOlderDaysIfNeeded()
                }
            }
        }
    }

    func maybeLoadOlderDaysIfNeeded() {
        guard !isLoadingOlderDays,
              let lastVisible = tableView.indexPathsForVisibleRows?.max(),
              !filteredDaySections.isEmpty else { return }

        let lastSection = filteredDaySections.count - 1
        let lastRow = filteredDaySections[lastSection].treatments.count - 1

        guard lastVisible.section >= max(0, lastSection - 1),
              lastVisible.row >= max(0, lastRow - 2) else { return }

        loadNextOlderDaySectionIfNeeded()
    }
    
    func syncSelectedDateFromVisibleSection() {
        guard !filteredDaySections.isEmpty else { return }
        let visibleRows = tableView.indexPathsForVisibleRows ?? []

        guard let topVisible = visibleRows.min(by: {
            if $0.section == $1.section { return $0.row < $1.row }
            return $0.section < $1.section
        }) else { return }

        let visibleDate = filteredDaySections[topVisible.section].date
        let cal = Calendar.current

        guard !cal.isDate(visibleDate, inSameDayAs: selectedDate) else { return }

        selectedDate = visibleDate
        datePicker.setDate(visibleDate, animated: true)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        syncSelectedDateFromVisibleSection()
        maybeLoadOlderDaysIfNeeded()
    }
    
    private func scrollToLatestNonFutureTreatmentForTodayIfNeeded() {
        let cal = Calendar.current
        guard cal.isDate(selectedDate, inSameDayAs: Date()),
              !hasAutoScrolledToTodayLatest else { return }

        let now = Date()

        if let sectionIndex = filteredSectionIndex(for: Date()) {
            let rows = filteredDaySections[sectionIndex].treatments
            if let rowIndex = rows.enumerated()
                .filter({ $0.element.timestamp <= now })
                .map({ $0.offset })
                .first {
                tableView.scrollToRow(
                    at: IndexPath(row: rowIndex, section: sectionIndex),
                    at: .top,
                    animated: false
                )
                hasAutoScrolledToTodayLatest = true
            }
        }
    }
    
    @objc func handleTreatmentsCacheUpdated(_ notification: Notification) {
        guard let updatedDayStart = notification.userInfo?["dayStart"] as? Date else { return }
        let cal = Calendar.current
        let selectedDayStart = cal.startOfDay(for: selectedDate)

        if cal.isDate(updatedDayStart, inSameDayAs: selectedDayStart) || daySectionIndex(for: updatedDayStart) != nil {
            loadSingleDaySection(for: updatedDayStart, reloadTable: true)
        }
    }

    @objc func handleGlobalTreatmentsUpdated(_ notification: Notification) {
        loadSingleDaySection(for: selectedDate, reloadTable: true)
    }
    
    @objc func dateChanged(_ sender: UIDatePicker) {
        selectedDate = sender.date
        hasAutoScrolledToTodayLatest = false

        if let sectionIndex = filteredSectionIndex(for: selectedDate),
           !filteredDaySections[sectionIndex].treatments.isEmpty {
            tableView.scrollToRow(
                at: IndexPath(row: 0, section: sectionIndex),
                at: .top,
                animated: true
            )
            syncSelectedDateFromVisibleSection()
        } else {
            loadInitialDaySections(anchoredAt: selectedDate)
        }
    }
}
