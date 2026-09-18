import UIKit

extension TreatmentsTableView {
    private func presentEditBGCheckViewController(for treatment: Treatment,
                                                  completionHandler: @escaping (Bool) -> Void) {
        let currentGlucose = (treatment.rawData["glucose"] as? Double) ?? 0.0

        let currentCreatedAt: Date = {
            if let rawCreatedAt = treatment.rawData["created_at"] as? String {
                let isoWithFractional = ISO8601DateFormatter()
                isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = isoWithFractional.date(from: rawCreatedAt) {
                    return date
                }

                let isoFallback = ISO8601DateFormatter()
                isoFallback.formatOptions = [.withInternetDateTime]
                if let date = isoFallback.date(from: rawCreatedAt) {
                    return date
                }
            }

            return treatment.timestamp
        }()

        let editorVC = BGCheckEditViewController(
            initialGlucose: currentGlucose,
            initialDate: currentCreatedAt
        )

        editorVC.onCancel = {
            completionHandler(false)
        }

        editorVC.onSave = { [weak self] updatedGlucose, updatedDate in
            guard let self else {
                completionHandler(false)
                return
            }

            self.saveEditedBGCheck(
                treatment: treatment,
                updatedGlucose: updatedGlucose,
                updatedDate: updatedDate,
                completionHandler: completionHandler
            )
        }

        let nav = UINavigationController(rootViewController: editorVC)
        nav.modalPresentationStyle = .pageSheet

        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }

        present(nav, animated: true)
    }
    
    func presentEditNoteViewController(for treatment: Treatment,
                                               completionHandler: @escaping (Bool) -> Void) {
        let currentNotes = (treatment.rawData["notes"] as? String) ?? ""

        let currentCreatedAt: Date = {
            if let rawCreatedAt = treatment.rawData["created_at"] as? String {
                let isoWithFractional = ISO8601DateFormatter()
                isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = isoWithFractional.date(from: rawCreatedAt) {
                    return date
                }

                let isoFallback = ISO8601DateFormatter()
                isoFallback.formatOptions = [.withInternetDateTime]
                if let date = isoFallback.date(from: rawCreatedAt) {
                    return date
                }
            }

            return treatment.timestamp
        }()

        let editorVC = NoteEditViewController(
            initialNotes: currentNotes,
            initialDate: currentCreatedAt
        )

        editorVC.onCancel = {
            completionHandler(false)
        }

        editorVC.onSave = { [weak self] updatedNotes, updatedDate in
            guard let self else {
                completionHandler(false)
                return
            }

            self.saveEditedNote(
                treatment: treatment,
                updatedNotes: updatedNotes,
                updatedDate: updatedDate,
                completionHandler: completionHandler
            )
        }

        let nav = UINavigationController(rootViewController: editorVC)
        nav.modalPresentationStyle = .pageSheet

        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }

        present(nav, animated: true)
    }
    
    private func saveEditedBGCheck(treatment: Treatment,
                                   updatedGlucose: Double,
                                   updatedDate: Date,
                                   completionHandler: @escaping (Bool) -> Void) {
        guard let treatmentId = treatment.documentId else {
            self.showAlert(title: "Fel", message: "Saknar dokument-ID för behandlingen") { }
            completionHandler(false)
            return
        }

        NightscoutUtils.fetchTreatmentById(treatmentId) { result in
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    self.showAlert(title: "Fel", message: error.localizedDescription) { }
                    completionHandler(false)
                }

            case .success(var doc):
                doc.removeValue(forKey: "_id")

                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                iso.timeZone = TimeZone(secondsFromGMT: 0)

                let createdAtString = iso.string(from: updatedDate)
                let originalTimestamp = treatment.timestamp

                doc["glucose"] = updatedGlucose
                doc["created_at"] = createdAtString
                //doc["timestamp"] = Int(updatedDate.timeIntervalSince1970 * 1000)
                //doc["mills"] = Int(updatedDate.timeIntervalSince1970 * 1000)
                doc["utcOffset"] = 0

                NightscoutUtils.executeDeleteRequest(treatmentId: treatmentId) { deleteResult in
                    switch deleteResult {
                    case .failure(let error):
                        DispatchQueue.main.async {
                            self.showAlert(title: "Kunde inte radera", message: error.localizedDescription) { }
                            completionHandler(false)
                        }

                    case .success:
                        Task {
                            do {
                                let createdDoc = try await NightscoutUtils.executePostRequestRaw(
                                    eventType: .treatments,
                                    body: doc
                                )

                                DispatchQueue.main.async {
                                    let oldDayStart = Calendar.current.startOfDay(for: originalTimestamp)
                                    let newDayStart = Calendar.current.startOfDay(for: updatedDate)

                                    if let index = self.treatments.firstIndex(where: { $0.documentId == treatment.documentId }) {
                                        let removed = self.treatments.remove(at: index)
                                        self.removeTreatmentFromCache(removed)

                                        if let createdDoc = createdDoc,
                                           let newTreatment = Treatment(dictionary: createdDoc as [String: AnyObject]) {
                                            self.treatments.insert(newTreatment, at: index)
                                            NightscoutCache.upsertTreatment(from: createdDoc)
                                        }
                                    } else if let createdDoc = createdDoc,
                                              let newTreatment = Treatment(dictionary: createdDoc as [String: AnyObject]) {
                                        self.treatments.insert(newTreatment, at: 0)
                                        NightscoutCache.upsertTreatment(from: createdDoc)
                                    }

                                    if oldDayStart != newDayStart {
                                        self.refreshTableKeepingSelectionIfNeeded()
                                    }

                                    self.tableView.reloadData()
                                    self.updateDuplicateIndicator()
                                    completionHandler(true)
                                }
                            } catch {
                                NightscoutUtils.addPendingUploadDocument(doc)

                                DispatchQueue.main.async {
                                    self.showAlert(
                                        title: "Kunde inte spara",
                                        message: "\nFingerstick-värdet kunde inte laddas upp just nu. Det kommer att laddas upp automatiskt nästa gång Behandlingslogg öppnas."
                                    ) { }
                                    completionHandler(false)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func saveEditedNote(treatment: Treatment,
                                updatedNotes: String,
                                updatedDate: Date,
                                completionHandler: @escaping (Bool) -> Void) {
        guard let treatmentId = treatment.documentId else {
            self.showAlert(title: "Fel", message: "Saknar dokument-ID för behandlingen") { }
            completionHandler(false)
            return
        }

        NightscoutUtils.fetchTreatmentById(treatmentId) { result in
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    self.showAlert(title: "Fel", message: error.localizedDescription) { }
                    completionHandler(false)
                }

            case .success(var doc):
                doc.removeValue(forKey: "_id")

                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                iso.timeZone = TimeZone(secondsFromGMT: 0)

                let createdAtString = iso.string(from: updatedDate)
                //let millis = Int(updatedDate.timeIntervalSince1970 * 1000)
                let originalTimestamp = treatment.timestamp

                doc["notes"] = updatedNotes
                doc["created_at"] = createdAtString
                //doc["timestamp"] = millis
                //doc["mills"] = millis
                doc["utcOffset"] = 0

                NightscoutUtils.executeDeleteRequest(treatmentId: treatmentId) { deleteResult in
                    switch deleteResult {
                    case .failure(let error):
                        DispatchQueue.main.async {
                            self.showAlert(title: "Kunde inte radera", message: error.localizedDescription) { }
                            completionHandler(false)
                        }

                    case .success:
                        Task {
                            do {
                                let createdDoc = try await NightscoutUtils.executePostRequestRaw(
                                    eventType: .treatments,
                                    body: doc
                                )

                                DispatchQueue.main.async {
                                    let oldDayStart = Calendar.current.startOfDay(for: originalTimestamp)
                                    let newDayStart = Calendar.current.startOfDay(for: updatedDate)

                                    if let index = self.treatments.firstIndex(where: { $0.documentId == treatment.documentId }) {
                                        let removed = self.treatments.remove(at: index)
                                        self.removeTreatmentFromCache(removed)

                                        if let createdDoc = createdDoc,
                                           let newTreatment = Treatment(dictionary: createdDoc as [String: AnyObject]) {
                                            self.treatments.insert(newTreatment, at: index)
                                            NightscoutCache.upsertTreatment(from: createdDoc)
                                        }
                                    } else if let createdDoc = createdDoc,
                                              let newTreatment = Treatment(dictionary: createdDoc as [String: AnyObject]) {
                                        self.treatments.insert(newTreatment, at: 0)
                                        NightscoutCache.upsertTreatment(from: createdDoc)
                                    }

                                    if oldDayStart != newDayStart {
                                        self.refreshTableKeepingSelectionIfNeeded()
                                    }

                                    self.tableView.reloadData()
                                    self.updateDuplicateIndicator()
                                    completionHandler(true)
                                }
                            } catch {
                                NightscoutUtils.addPendingUploadDocument(doc)

                                DispatchQueue.main.async {
                                    self.showAlert(
                                        title: "Kunde inte spara",
                                        message: "\nNoteringen kunde inte laddas upp just nu. Den kommer att laddas upp automatiskt nästa gång Behandlingslogg öppnas."
                                    ) { }
                                    completionHandler(false)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Called when an alert is dismissed (e.g. after cancellation or authentication failure).
}
