import UIKit

extension TreatmentsTableView {
    func updateDuplicateIndicator() {
        // Check if any duplicate exists in the filtered treatments, excluding "Note" eventType
        let duplicatesExist = filteredTreatments.contains { treatment in
            guard treatment.eventType != "Note" else { return false }
            
            let count = filteredTreatments.filter {
                $0.timestamp == treatment.timestamp &&
                $0.eventType == treatment.eventType &&
                $0.eventType != "Note"
            }.count
            
            return count > 1
        }
        
        // Determine which refresh button to show: if a refresh is in progress, use the activity indicator.
        let refreshButton: UIBarButtonItem
        if let indicator = activityIndicator {
            refreshButton = UIBarButtonItem(customView: indicator)
        } else {
            refreshButton = makeRefreshBarButtonItem()
        }
        
        if duplicatesExist {
            let duplicateIndicator = UIBarButtonItem(
                image: UIImage(systemName: "document.on.document"),
                style: .plain,
                target: self,
                action: #selector(duplicateIndicatorTapped)
            )
            duplicateIndicator.tintColor = .systemRed
            navigationItem.leftBarButtonItems = [refreshButton, duplicateIndicator]
        } else {
            navigationItem.leftBarButtonItems = [refreshButton]
        }
    }
    
    @objc private func duplicateIndicatorTapped() {
        // Find the first non-Note treatment that has a duplicate (same timestamp and event type)
        if let duplicateIndex = filteredTreatments.firstIndex(where: { treatment in
            guard treatment.eventType != "Note" else { return false }
            
            let duplicateCount = filteredTreatments.filter {
                $0.timestamp == treatment.timestamp &&
                $0.eventType == treatment.eventType &&
                $0.eventType != "Note"
            }.count
            return duplicateCount > 1
        }) {
            let indexPath = IndexPath(row: duplicateIndex, section: 0)
            tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
        }
    }
    
    // MARK: - Refresh Button Action
    
    @objc func refreshButtonTapped() {
        // Trigger the same global refresh logic used in MainViewController
        NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)

        // Show local loading indicator immediately so the user sees that work has started
        showRefreshIndicator()

        // Reset picker to today and allow a new auto-scroll to latest for today.
        selectedDate = Date()
        hasAutoScrolledToTodayLatest = false
        datePicker.setDate(selectedDate, animated: true)

        // We no longer guess with a fixed delay. When MainViewController has
        // finished fetching and processing treatments, it will post the
        // .treatmentsUpdated notification, which we listen for in
        // handleGlobalTreatmentsUpdated(_:) and reload from NightscoutCache.
    }

    @objc func refreshButtonLongPressed(_ gesture: UILongPressGestureRecognizer) {
        // Only trigger once when the long press begins
        guard gesture.state == .began else { return }
        
        let alert = UIAlertController(
            title: "Återfylla cache?",
            message: "Vill du hämta 90 dagars behandlingshistorik från Nightscout?\n\nHämtningen kan ta ett par minuter, så ha tålamod.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Hämta", style: .default, handler: { [weak self] _ in
            self?.startBackfillLast90Days()
        }))
        
        present(alert, animated: true, completion: nil)
    }

    /// Manuell 90-dagars återfyllnad av behandlingshistorik från Nightscout.
    /// Hämtar alla treatments inom cache-fönstret (ca 90 dagar) och upsertar dem i NightscoutCache.
    private func startBackfillLast90Days() {
        // Visa samma indikator som vid vanlig refresh
        showRefreshIndicator()
        
        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        
        // Äldsta dag i cache-fönstret: samma logik som för datePicker.minimumDate
        let oldestDay = cal.date(byAdding: .day,
                                 value: -NightscoutCache.retentionDays + 1,
                                 to: todayStart) ?? todayStart
        
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        // Använd lokal tidszon för att täcka hela kalenderdygnen
        iso.timeZone = .current
        
        let params: [String: String] = [
            "find[created_at][$gte]": iso.string(from: oldestDay),
            "find[created_at][$lte]": iso.string(from: now),
            "count": "50000"
        ]
        
        NightscoutUtils.executeDynamicRequest(eventType: .treatments, parameters: params) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let raw):
                    if let entries = raw as? [[String: AnyObject]] {
                        // Upsert:a samtliga treatments i cache. upsertTreatment bör hantera dubletter via _id.
                        NightscoutCache.upsertTreatments(from: entries.map { $0 as [String: Any] })
                        
                        // Ladda om aktuell dag från cache (om användaren står på en dag inom fönstret).
                        self.loadTreatments(for: self.selectedDate)
                        
                        // Visa en liten bekräftelse-overlay
                        self.showDateSyncOverlay(message: "Cache återfylld med \(entries.count) behandlingar")
                    } else {
                        self.showAlert(title: "Fel", message: "Kunde inte tolka behandlingsdata från Nightscout") { }
                    }
                case .failure(let error):
                    self.showAlert(
                        title: "Kunde inte hämta historik",
                        message: "\n\(error.localizedDescription)"
                    ) { }
                }
                
                // Återställ refresh-knappen
                self.hideRefreshIndicator()
            }
        }
    }
    
    func showRefreshIndicator() {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.startAnimating()
        self.activityIndicator = indicator
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: indicator)
    }
    
    func hideRefreshIndicator() {
        activityIndicator = nil
        updateDuplicateIndicator()
    }
    
    @objc private func refreshTreatments(_ sender: UIRefreshControl) {
        loadTreatments()
        // End refreshing after data is loaded; you might also call this in the completion of loadTreatments()
        sender.endRefreshing()
    }
}
