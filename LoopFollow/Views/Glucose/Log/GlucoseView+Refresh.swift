import UIKit
import Charts

extension GlucoseView {
    @objc func refreshButtonTapped() {
        showRefreshIndicator()
        if dataMode == .sensorErrors {
            Task { await loadSensorErrors90Days() }
            return
        }
        Task {
            await backfillLastDays(backfillDays)
            DispatchQueue.main.async {
                self.loadBG(for: self.selectedDate)
            }
        }
    }

    @objc func refreshButtonLongPressed(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began, !isCompressionBackfillRunning else { return }

        showRefreshIndicator()
        if dataMode == .sensorErrors {
            // Restore the glucose evidence as well as rebuilding the cached notes.
            Task {
                await backfillLastDays(sensorErrorLookbackDays)
                await loadSensorErrors90Days()
            }
            return
        }
        isCompressionBackfillRunning = true
        Task {
            await backfillLastDays(initialBackfillDays)
            let end = Date()
            let start = end.addingTimeInterval(-90 * 24 * 3600)
            let threshold = Double(UserDefaultsRepository.alertLowBG.value)
            let observations = await Task.detached(priority: .utility) {
                let (readings, _) = await NightscoutCache.loadWindow(from: start.addingTimeInterval(-30 * 60), to: end)
                return SuspectedCompressionLowHistory.calculateSuspectedCompressionLows(readings,
                    from: start.timeIntervalSince1970, to: end.timeIntervalSince1970, lowThreshold: threshold)
            }.value
            // Read current storage after the await so live detections and edits during the scan are retained.
            var history = Storage.shared.suspectedCompressionLowHistory
            var sensors = Storage.shared.sensorStartNotes
            history.mergeHistorical(observations, sensors: &sensors)
            Storage.shared.suspectedCompressionLowHistory = history
            Storage.shared.sensorStartNotes = sensors
            NotificationCenter.default.post(name: SiteSessionService.didUpdate, object: nil)
            isCompressionBackfillRunning = false
            self.loadBG(for: self.selectedDate)
            let message = observations.isEmpty
                ? "Det finns inte tillräckligt med sammanhängande glukosdata att analysera. Befintliga träffar finns kvar."
                : "Analyserade \(observations.count) glukosvärden från de senaste 90 dagarnas tillgängliga data. 🗜️ visar misstänkta träffar; sitestatistiken räknar sammanhängande episoder. Historiken använder glukosmönstret och din nuvarande låggräns, utan kontroll av historiskt IOB."
            let alert = UIAlertController(title: "Återfyllning av comp. low", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            if self.viewIfLoaded?.window != nil, self.presentedViewController == nil { self.present(alert, animated: true) }
        }
    }

    /// Fetches X days back from Nightscout into both glucose caches.
    /// Overwrites existing cached days only if needed.
    private func backfillLastDays(_ days: Int) async {
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: now))!

        //print("🔄 Backfilling \(days) days (NS-only glucose): \(start) → \(now)")

        let sgvBatch = await NightscoutUtils.fetchSGVWindow(from: start, to: now)
        if !sgvBatch.isEmpty {
            GlucoseNSOnlyCache.mergeSGVBatch(sgvBatch)
            NightscoutCache.mergeSGVBatch(sgvBatch)
            GlucoseNSOnlyCache.purgeOldFiles()
        }

        //print("✅ NS-only glucose backfill completed.")
    }

    /// Ensure that we have performed the large initial NS-only backfill once (90 days).
    func ensureInitialBackfill() async {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: initialBackfillFlagKey) {
            return
        }

        await backfillLastDays(initialBackfillDays)
        defaults.set(true, forKey: initialBackfillFlagKey)
    }

    /// Refresh NS-only cache for the most recent window (default 24h).
    /// This makes sure Trio→NS gaps are up-to-date as soon as the view is opened.
    func refreshNSOnlyCacheRecent(hours: Int = 24) async {
        let now = Date()

        // Throttle
        if let last = lastNSOnly24hRefreshAt, now.timeIntervalSince(last) < nsOnly24hRefreshMinInterval {
            return
        }
        lastNSOnly24hRefreshAt = now

        let start = now.addingTimeInterval(-TimeInterval(hours) * 3600)

        let sgvBatch = await NightscoutUtils.fetchSGVWindow(from: start, to: now)
        if !sgvBatch.isEmpty {
            GlucoseNSOnlyCache.mergeSGVBatch(sgvBatch)
            GlucoseNSOnlyCache.purgeOldFiles()
        }
    }

    func showRefreshIndicator() {
        guard reloadIndicator == nil, let reloadButton = reloadButton else { return }

        let ind = UIActivityIndicatorView(style: .medium)
        ind.startAnimating()
        reloadIndicator = ind

        let indicatorItem = UIBarButtonItem(customView: ind)

        if var items = navigationItem.leftBarButtonItems {
            if let idx = items.firstIndex(where: { $0 === reloadButton }) {
                items[idx] = indicatorItem
                navigationItem.leftBarButtonItems = items
            }
        }
    }

    func hideRefreshIndicator() {
        guard let reloadButton = reloadButton else { return }

        if let ind = reloadIndicator {
            ind.stopAnimating()
            reloadIndicator = nil
        }

        if var items = navigationItem.leftBarButtonItems {
            // Replace indicator with reload button
            if let idx = items.firstIndex(where: { ($0.customView as? UIActivityIndicatorView) != nil }) {
                items[idx] = reloadButton
                navigationItem.leftBarButtonItems = items
            }
        }
    }

}
