import UIKit

extension TreatmentsTableView {
    func showAlert(title: String, message: String, completion: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            completion()
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    func handleAlertDismissal() {
        // For example, re-enable any disabled buttons; here we simply log.
        LogManager.shared.log(category: .treatments, message: "Alert dismissed, re-enabling controls if needed.", isDebug: true)
    }

    
    // MARK: - UITableViewDelegate Methods
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        
        let treatment = treatment(for: indexPath)
        
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "sv_SE")
        timeFormatter.dateFormat = "dd MMM HH:mm:ss"
        let timeString = timeFormatter.string(from: treatment.timestamp)

        // Nightscout meta: who created the treatment
        let enteredByValue: String? = {
            if let v = treatment.rawData["enteredBy"] as? String, !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return v
            }
            // Some NS setups / middleware may use different casing
            if let v = treatment.rawData["entered_by"] as? String, !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return v
            }
            if let v = treatment.rawData["EnteredBy"] as? String, !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return v
            }
            return nil
        }()

        func withEnteredBy(_ base: String) -> String {
            guard let enteredBy = enteredByValue else { return base }
            return base + "\n\nInlagt av: \(enteredBy)"
        }

        func presentAlert(title: String, message: String) {
            //let alert = UIAlertController(title: title, message: withEnteredBy(message), preferredStyle: .alert)
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                tableView.deselectRow(at: indexPath, animated: true)
            })
            present(alert, animated: true)
        }
        
        if treatment.eventType == "SMB" || treatment.eventType == "Temp Basal" {
            let adjustedTimestamp = treatment.timestamp.addingTimeInterval(30)
            NightscoutUtils.fetchDeviceStatusReasonBeforeTimestamp(timestamp: adjustedTimestamp) { result in
                switch result {
                case .success(let reason):
                    let formattedReason = self.formatReason(reason)
                    presentAlert(title: "Trio behandlingsbeslut", message: formattedReason)
                case .failure(let error):
                    presentAlert(title: "Fel", message: error.localizedDescription)
                }
            }
        }
        
        if treatment.eventType == "Note" || treatment.eventType == "Announcement" {
            if let fullNote = treatment.rawData["notes"] as? String {
                var modifiedNote = fullNote
                modifiedNote = modifiedNote.replacingOccurrences(of: "PumpResume", with: "Pump startades")
                modifiedNote = modifiedNote.replacingOccurrences(of: "PumpSuspend", with: "Pump pausades")
                //modifiedNote = modifiedNote.replacingOccurrences(of: "⚠️ ", with: "")
                var message = modifiedNote
                if let enteredBy = treatment.rawData["enteredBy"] as? String {
                    message += "\nInlagt av: \(enteredBy)"
                }
                presentAlert(title: "\(timeString)\n\nNotering", message: message)
                
            }
        }
        
        if ["Sensor Start", "Sensor Change", "Sensorbyte", "Sensorstart"].contains(treatment.eventType) {
            let title = "\(timeString)\n\nSensorbyte"
            var message = treatment.sensorStartNotes ?? "Inga anteckningar"
            if let enteredBy = treatment.rawData["enteredBy"] as? String {
                message += "\nInlagt av: \(enteredBy)"
            }
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Analysera Sensorbyte", style: .default, handler: { _ in
                let events = self.buildEventsArray()
                let analysisStart = treatment.timestamp.addingTimeInterval(-30) // minus 30 s
                let analysisEnd = treatment.timestamp.addingTimeInterval(21570) // end 360 min after start
                let analysisVC = MealAnalysisView(events: events, initialStart: analysisStart, initialEnd: analysisEnd, modalWithTimestamp: true, modalTitleString: "Analys sensorbyte", preSelectedSegment: 3)
                let nav = UINavigationController(rootViewController: analysisVC)
                nav.modalPresentationStyle = .formSheet
                self.present(nav, animated: true)
            }))
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                tableView.deselectRow(at: indexPath, animated: true)
            }))
            self.present(alert, animated: true)
        }
        
        if treatment.eventType == "Site Change" {
            let title = "\(timeString)\n\nPoddbyte"
            var message = ""
            if let enteredBy = treatment.rawData["enteredBy"] as? String {
                message = "Inlagt av: \(enteredBy)"
            }
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Analysera Poddbyte", style: .default, handler: { _ in
                let events = self.buildEventsArray()
                let analysisStart = treatment.timestamp.addingTimeInterval(-10800) // minus 3h
                let analysisEnd = treatment.timestamp.addingTimeInterval(10800) // end 3h after start
                let analysisVC = MealAnalysisView(events: events, initialStart: analysisStart, initialEnd: analysisEnd, modalWithTimestamp: true, modalTitleString: "Analys podd", preSelectedSegment: 3)
                let nav = UINavigationController(rootViewController: analysisVC)
                nav.modalPresentationStyle = .formSheet
                self.present(nav, animated: true)
            }))
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                tableView.deselectRow(at: indexPath, animated: true)
            }))
            self.present(alert, animated: true)
        }
        
        if treatment.eventType == "BG Check" {
            if let glucose = treatment.rawData["glucose"] as? Double,
               let units = treatment.rawData["units"] as? String {
                let mmol = units.lowercased().contains("mmol") ? glucose : glucose / 18.0
                let title = "\(timeString)\n\nFingerstick"
                var message = "Blodsocker: \(glucose) mmol/L"
                if let enteredBy = treatment.rawData["enteredBy"] as? String {
                    message += "\nInlagt av: \(enteredBy)"
                }
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Analys stick", style: .default, handler: { _ in
                    let events = self.buildEventsArray()
                    let analysisStart = treatment.timestamp.addingTimeInterval(-1200) // minus 20 min
                    let analysisEnd = treatment.timestamp.addingTimeInterval(9600) // end 180 min after start - använder nil tillsvidare
                    let analysisVC = MealAnalysisView(events: events, initialStart: analysisStart, initialEnd: nil, modalWithTimestamp: true, modalTitleString: "Analys stick", preSelectedSegment: 2)
                    let nav = UINavigationController(rootViewController: analysisVC)
                    nav.modalPresentationStyle = .formSheet
                    self.present(nav, animated: true)
                }))
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    tableView.deselectRow(at: indexPath, animated: true)
                }))
                self.present(alert, animated: true)
            }
        }
        
        if ["Temporary Override", "Exercise", "Override"].contains(treatment.eventType) {
            if let fullOverride = treatment.overrideNotes {
                let title = "\(timeString)\n\nOverride"
                var message = fullOverride
                if let duration = treatment.overrideDuration {
                    // Show “Tillsvidare” if duration > 1439 minutes
                    if duration > 1439 {
                        message += "\nVaraktighet: Tillsvidare"
                    } else {
                        message += "\nVaraktighet: \(Int(duration)) min"
                    }
                    let expirationTime = treatment.timestamp.addingTimeInterval(duration * 60)
                    message += "\nAktiv till kl: \(timeFormatter.string(from: expirationTime))"
                }
                if let enteredBy = treatment.rawData["enteredBy"] as? String {
                    message += "\nInlagt av: \(enteredBy)"
                }
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Analys override", style: .default, handler: { _ in
                    let events = self.buildEventsArray()
                    let analysisStart = treatment.timestamp.addingTimeInterval(-30) // minus 30 s
                    let analysisEnd = treatment.timestamp.addingTimeInterval(9600) // end 180 min after start - använder nil tillsvidare
                    let analysisVC = MealAnalysisView(events: events, initialStart: analysisStart, initialEnd: nil, modalWithTimestamp: true, modalTitleString: "Analys override", preSelectedSegment: 2)
                    let nav = UINavigationController(rootViewController: analysisVC)
                    nav.modalPresentationStyle = .formSheet
                    self.present(nav, animated: true)
                }))
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    tableView.deselectRow(at: indexPath, animated: true)
                }))
                self.present(alert, animated: true)
            }
        }

        if treatment.eventType == "Carb Correction" {
            let foodTypeValue = treatment.rawData["foodType"] as? String ?? ""
            let isDextro = foodTypeValue.contains("🍬")
            let title: String
            if isDextro {
                title = "\(timeString)\n\nDextro"
            } else {
                title = foodTypeValue.isEmpty
                    ? "\(timeString)\n\nFett & Protein"
                    : "\(timeString)\n\nMåltid"
            }
            var message: String
            if isDextro {
                message = foodTypeValue
            } else {
                message = foodTypeValue.isEmpty
                    ? "Kolhydratsekvivalenter: "
                    : foodTypeValue
            }
            let carbsValue: Double = treatment.rawData["carbs"] as? Double ?? 0.0
            message += foodTypeValue.isEmpty ? "\(formatValue(carbsValue)) g" : "\nKolhydrater: \(formatValue(carbsValue)) g"
            if let fatValue = treatment.rawData["fat"] as? Double, fatValue != 0 {
                message += "\nFett: \(formatValue(fatValue)) g"
            }
            if let proteinValue = treatment.rawData["protein"] as? Double, proteinValue != 0 {
                message += "\nProtein: \(formatValue(proteinValue)) g"
            }
            if let enteredBy = treatment.rawData["enteredBy"] as? String {
                message += "\nInlagt av: \(enteredBy)"
            }
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: isDextro ? "Analys dextro" : "Analys måltid", style: .default, handler: { _ in
                let events = self.buildEventsArray()
                let analysisStart = treatment.timestamp.addingTimeInterval(-30) // minus 30 s
                let analysisEnd = treatment.timestamp.addingTimeInterval(10770) // end 180 min after start - använder nil tillsvidare
                let analysisStartDextro = treatment.timestamp.addingTimeInterval(-1200) // minus 20 min
                let analysisEndDextro = treatment.timestamp.addingTimeInterval(9600) // end 180 min after start - använder nil tillsvidare
                let analysisVC = MealAnalysisView(events: events, initialStart: isDextro ? analysisStartDextro : analysisStart, initialEnd: isDextro ? analysisEndDextro : analysisEnd, modalWithTimestamp: true, modalTitleString: isDextro ? "Analys dextro" : "Analys måltid", preSelectedSegment: 2)
                let nav = UINavigationController(rootViewController: analysisVC)
                nav.modalPresentationStyle = .formSheet
                self.present(nav, animated: true)
            }))
            alert.addAction(UIAlertAction(title: "Samma tid dagen innan", style: .default, handler: { _ in
                let events = self.buildEventsArray()
                let oneDayBackStartIntervall = -(24 * 60 * 60 + 60 * 60) //igår + 60min tillbaka
                let oneDayBackEndIntervall = oneDayBackStartIntervall + 21600 //360 min efter start igår - använder nil tillsvidare
                let analysisStart = treatment.timestamp.addingTimeInterval(Double(oneDayBackStartIntervall))
                let analysisEnd = treatment.timestamp.addingTimeInterval(Double(oneDayBackEndIntervall))
                let analysisVC = MealAnalysisView(events: events, initialStart: analysisStart, initialEnd: nil, modalWithTimestamp: true, modalTitleString: "Analys tid", preSelectedSegment: 3)
                let nav = UINavigationController(rootViewController: analysisVC)
                nav.modalPresentationStyle = .formSheet
                self.present(nav, animated: true)
            }))
            alert.addAction(UIAlertAction(title: "Samma tid veckan innan", style: .default, handler: { _ in
                let events = self.buildEventsArray()
                let oneWeekBackStartIntervall = -(7 * 24 * 60 * 60 + 60 * 60) //1 vecka och 60min tillbaka
                let oneWeekBackEndIntervall = oneWeekBackStartIntervall + 21600 //360 min efter start en vecka tillbaka - använder nil tillsvidare
                let analysisStart = treatment.timestamp.addingTimeInterval(Double(oneWeekBackStartIntervall))
                let analysisEnd = treatment.timestamp.addingTimeInterval(Double(oneWeekBackEndIntervall))
                let analysisVC = MealAnalysisView(events: events, initialStart: analysisStart, initialEnd: nil, modalWithTimestamp: true, modalTitleString: "Analys tid", preSelectedSegment: 3)
                let nav = UINavigationController(rootViewController: analysisVC)
                nav.modalPresentationStyle = .formSheet
                self.present(nav, animated: true)
            }))
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                tableView.deselectRow(at: indexPath, animated: true)
            }))
            self.present(alert, animated: true)
        }

        if treatment.eventType == "Bolus" {
            let bolusValue = treatment.amount ?? "0.0"
            var message = "Insulin: \(bolusValue)"
            if let enteredBy = treatment.rawData["enteredBy"] as? String {
                message += "\nInlagt av: \(enteredBy)"
            }
            presentAlert(title: "\(timeString)\n\nBolus", message: message)
        }
    }

    
    func deselectRowAfterAlert(_ tableView: UITableView, indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
