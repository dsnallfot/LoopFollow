import UIKit

extension TreatmentsTableView {
    private func matchesTreatment(_ candidate: Treatment, _ treatment: Treatment) -> Bool {
        if let id = treatment.documentId {
            return candidate.documentId == id
        }
        return candidate.documentId == nil &&
            candidate.timestamp == treatment.timestamp &&
            candidate.eventType == treatment.eventType
    }

    func applyLocalTreatmentDeletion(_ treatment: Treatment) {
        for index in daySections.indices {
            daySections[index].treatments.removeAll { matchesTreatment($0, treatment) }
        }
        rebuildTreatmentsFlatCache()
        removeTreatmentFromCache(treatment)
        tableView.reloadData()
        updateDuplicateIndicator()
    }

    func restoreLocalTreatment(_ treatment: Treatment) {
        NightscoutCache.upsertTreatment(from: treatment.rawData)
        if let index = daySectionIndex(for: treatment.timestamp) {
            if !daySections[index].treatments.contains(where: { matchesTreatment($0, treatment) }) {
                daySections[index].treatments.append(treatment)
                daySections[index].treatments.sort { $0.timestamp > $1.timestamp }
            }
            rebuildTreatmentsFlatCache()
            tableView.reloadData()
            updateDuplicateIndicator()
        }
    }

    /// Remove the treatment from the local cache while remote deletion is processed.
    func removeTreatmentFromCache(_ treatment: Treatment) {
        let possibleDates: [Date] = {
            if let rawCreatedAt = treatment.rawData["created_at"] as? String {
                let isoWithFractional = ISO8601DateFormatter()
                isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = isoWithFractional.date(from: rawCreatedAt) {
                    return [date, treatment.timestamp]
                }

                let isoFallback = ISO8601DateFormatter()
                isoFallback.formatOptions = [.withInternetDateTime]
                if let date = isoFallback.date(from: rawCreatedAt) {
                    return [date, treatment.timestamp]
                }
            }
            return [treatment.timestamp]
        }()

        let uniqueDayStarts = Array(Set(possibleDates.map { Calendar.current.startOfDay(for: $0) }))

        for dayStart in uniqueDayStarts {
            guard var payload = try? NightscoutCache.readDay(dayStart) else { continue }

            if let id = treatment.documentId {
                payload.treatments.removeAll { $0._id == id }
            } else {
                payload.treatments.removeAll {
                    $0.created_at == treatment.timestamp && $0.eventType == treatment.eventType
                }
            }

            try? NightscoutCache.writeDay(date: dayStart,
                                          sgv: payload.sgv,
                                          treatments: payload.treatments)
        }
    }

    func refreshTableKeepingSelectionIfNeeded() {
        treatments.sort { $0.timestamp > $1.timestamp }
    }

    // MARK: - Rolling Window Freshness Refresh for Today

    /// Lightweight refresh for “today”: fetch rolling window from Nightscout,
    /// update the table, and overwrite the treatments portion of NightscoutCache
    /// for the affected days so MainVC can update immediately and deletions/edits
    /// are reflected (not just additions).
    private func refreshRollingTreatmentsForToday() {
        let now = Date()
        let hours = 24 * max(1, UserDefaultsRepository.downloadDays.value)
        let since = now.addingTimeInterval(-Double(hours) * 60 * 60)

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        iso.timeZone = TimeZone(secondsFromGMT: 0)

        let params: [String: String] = [
            "find[created_at][$gte]": iso.string(from: since),
            "find[created_at][$lte]": iso.string(from: now)
        ]

        NightscoutUtils.executeDynamicRequest(eventType: .treatments, parameters: params) { result in
            DispatchQueue.main.async {
                guard case .success(let raw) = result,
                      let entries = raw as? [[String: AnyObject]] else {
                    return
                }

                // Parse fetched treatments
                let fetched = entries.compactMap { Treatment(dictionary: $0) }

                // Update table contents (even if empty)
                self.treatments = fetched.sorted { $0.timestamp > $1.timestamp }
                self.tableView.reloadData()
                self.updateDuplicateIndicator()

                // Overwrite cache treatments for all days in the rolling window
                self.overwriteTreatmentsCacheForRollingWindow(
                    start: since,
                    end: now,
                    fetchedTreatments: fetched
                )

                // Notify MainVC that cache has fresh treatment data
                NotificationCenter.default.post(
                    name: NSNotification.Name("TreatmentsCacheUpdated"),
                    object: nil
                )
            }
        }
    }

    /// Overwrite the *treatments* slice of the NightscoutCache for each calendar day
    /// covered by the rolling window. We preserve cached SGV data for each day.
    private func overwriteTreatmentsCacheForRollingWindow(start: Date, end: Date, fetchedTreatments: [Treatment]) {
        let cal = Calendar.current

        // Build the set of day-starts to rewrite (inclusive range)
        let startDay = cal.startOfDay(for: start)
        let endDay = cal.startOfDay(for: end)

        var dayCursor = startDay
        while dayCursor <= endDay {
            // Treatments that belong to this local calendar day
            let dayStart = dayCursor
            guard let nextDay = cal.date(byAdding: .day, value: 1, to: dayStart) else { break }

            let dayTreatments = fetchedTreatments.filter { t in
                t.timestamp >= dayStart && t.timestamp < nextDay
            }

            // Preserve existing SGV data for this day if present
            let existingPayload = try? NightscoutCache.readDay(dayStart)
            let preservedSGV = existingPayload?.sgv ?? []

            // Convert Treatment -> CachedTreatment (NightscoutCache model)
            // by going through the same mapping used elsewhere: we rely on upsertTreatment
            // only for conversion convenience, but we overwrite the day file below.
            // We build cached treatments by re-reading the day after per-doc upserts.

            // First: upsert all treatments for this day so the cache has valid encoded objects
            // (this does NOT delete anything by itself).
            for t in dayTreatments {
                // If we have rawData for a treatment, prefer using that for upsert.
                // Otherwise, fall back to a minimal document.
                var doc: [String: AnyObject] = t.rawData
                if doc["_id"] == nil, let id = t.documentId as AnyObject? { doc["_id"] = id }
                if doc["eventType"] == nil { doc["eventType"] = t.eventType as AnyObject }
                if doc["created_at"] == nil {
                    let fmt = ISO8601DateFormatter()
                    fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    doc["created_at"] = fmt.string(from: t.timestamp) as AnyObject
                }
                NightscoutCache.upsertTreatment(from: doc)
            }

            // Now rebuild the day file with ONLY the treatments for this day (deletions handled).
            // We read the day file (after upserts) and then filter to the IDs/timestamps we want.
            if var payload = try? NightscoutCache.readDay(dayStart) {
                // If the cache already had treatments, replace them. If not, start from empty.
                payload.treatments.removeAll()

                // Read back the upserted day and keep only treatments in this day’s range.
                // (NightscoutCache stores per-day already, so just take its treatments list.)
                // If readDay succeeded, payload.treatments currently corresponds to that day.
                // However we cleared it above, so we need to re-read fresh.
                if let freshPayload = try? NightscoutCache.readDay(dayStart) {
                    // Filter to this exact day window to be safe
                    let filtered = freshPayload.treatments.filter { ct in
                        ct.created_at >= dayStart && ct.created_at < nextDay
                    }
                    payload.treatments = filtered
                }

                // Finally write the day back, preserving SGV
                try? NightscoutCache.writeDay(date: dayStart, sgv: preservedSGV, treatments: payload.treatments)
            } else {
                // No existing payload file – just write a new one with preserved SGV (empty)
                // and treatments derived from dayTreatments by reading the cache day after upserts.
                if let freshPayload = try? NightscoutCache.readDay(dayStart) {
                    let filtered = freshPayload.treatments.filter { ct in
                        ct.created_at >= dayStart && ct.created_at < nextDay
                    }
                    try? NightscoutCache.writeDay(date: dayStart, sgv: preservedSGV, treatments: filtered)
                } else {
                    try? NightscoutCache.writeDay(date: dayStart, sgv: preservedSGV, treatments: [])
                }
            }

            dayCursor = nextDay
        }
    }
}
