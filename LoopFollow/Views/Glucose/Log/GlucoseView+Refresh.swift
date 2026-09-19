import UIKit
import Charts

extension GlucoseView {
    @objc func refreshButtonTapped() {
        showRefreshIndicator()
        Task {
            await backfillLastDays(backfillDays)
            DispatchQueue.main.async {
                self.loadBG(for: self.selectedDate)
            }
        }
    }

    @objc func refreshButtonLongPressed(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }

        showRefreshIndicator()
        Task {
            await backfillLastDays(initialBackfillDays)
            await MainActor.run {
                self.loadBG(for: self.selectedDate)
            }
        }
    }

    /// Fetches X days back from Nightscout and writes SGVs into the NS-only glucose cache.
    /// Overwrites existing cached days only if needed.
    private func backfillLastDays(_ days: Int) async {
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .day, value: -days, to: now)!

        //print("🔄 Backfilling \(days) days (NS-only glucose): \(start) → \(now)")

        let sgvBatch = await NightscoutUtils.fetchSGVWindow(from: start, to: now)
        if !sgvBatch.isEmpty {
            GlucoseNSOnlyCache.mergeSGVBatch(sgvBatch)
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
