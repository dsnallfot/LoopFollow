import UIKit

extension TreatmentsTableView {
    // MARK: - Swipe to Delete (Editing Style)
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let treatment = treatment(for: indexPath)
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "sv_SE")
        timeFormatter.dateFormat = "HH:mm"
        let timeString = timeFormatter.string(from: treatment.timestamp)
        
        let deleteAction = UIContextualAction(style: .destructive, title: nil) { (action, view, completionHandler) in
            // Retrieve remote type from Storage.
            let remoteType = Storage.shared.remoteType.value

            // Offer remote meal deletion via SMS or TRC, and glucose deletion via TRC.
            if treatment.eventType == "Carb Correction",
               let foodType = treatment.rawData["foodType"] as? String, !foodType.isEmpty,
               remoteType == .sms {
                let alert = UIAlertController(
                    title: "Radera måltid?",
                    message: "\nVälj om du vill: \n\n• Radera måltiden i Trio (vilket också raderar den i Nightscout) \n\n• Radera endast måltiden i Nightscout (vilket INTE raderar den i Trio!)",
                    preferredStyle: .alert)

                alert.addAction(UIAlertAction(title: "Trio & Nightscout", style: .default, handler: { _ in
                    self.deleteEntryInTrio(for: treatment)
                    completionHandler(true)
                }))

                alert.addAction(UIAlertAction(title: "Endast Nightscout", style: .destructive, handler: { _ in
                    guard let treatmentId = treatment.documentId else {
                        completionHandler(false)
                        return
                    }
                    completionHandler(true)
                    self.applyLocalTreatmentDeletion(treatment)
                    NightscoutUtils.executeDeleteRequest(treatmentId: treatmentId) { result in
                        switch result {
                        case .success(_):
                            break
                        case .failure(let error):
                            DispatchQueue.main.async {
                                self.restoreLocalTreatment(treatment)
                                let failureAlert = UIAlertController(
                                    title: "Kunde inte radera!",
                                    message: "Kontrollera att du har skrivåtkomst i din Nightscout token",
                                    preferredStyle: .alert)
                                failureAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                                self.present(failureAlert, animated: true, completion: nil)
                            }
                            LogManager.shared.log(category: .treatments, message: "Failed to delete treatment: \(error.localizedDescription)", isDebug: true)
                        }
                    }
                }))

                alert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: { _ in
                    completionHandler(false)
                }))
                self.present(alert, animated: true, completion: nil)
            } else if remoteType == .trc,
                      treatment.eventType == "BG Check" ||
                      (treatment.eventType == "Carb Correction" &&
                       !(treatment.rawData["foodType"] as? String ?? "").isEmpty) {
                let isGlucose = treatment.eventType == "BG Check"
                let entryName = isGlucose ? "blodsockervärdet" : "måltiden"
                let alert = UIAlertController(
                    title: isGlucose ? "Radera blodsockervärde?" : "Radera måltid?",
                    message: "\nVälj om du vill: \n\n• Radera \(entryName) i Trio (vilket också raderar den i Nightscout) \n\n• Radera endast \(entryName) i Nightscout (vilket INTE raderar den i Trio!)",
                    preferredStyle: .alert
                )

                alert.addAction(UIAlertAction(title: "Trio & Nightscout", style: .default, handler: { _ in
                    completionHandler(true)
                    self.applyLocalTreatmentDeletion(treatment)
                    let pushNotificationManager = PushNotificationManager()
                    let completion: (Bool, String?) -> Void = { success, errorMessage in
                        DispatchQueue.main.async {
                            if !success {
                                self.restoreLocalTreatment(treatment)
                            }
                            let resultAlert = UIAlertController(
                                title: "Status",
                                message: success ? "Raderingskommando skickades" : (errorMessage ?? "Raderingskommando misslyckades"),
                                preferredStyle: .alert
                            )
                            resultAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                            self.present(resultAlert, animated: true, completion: nil)
                        }
                    }
                    if isGlucose {
                        pushNotificationManager.sendDeleteGlucosePushNotification(glucoseDate: treatment.timestamp, completion: completion)
                    } else {
                        pushNotificationManager.sendDeleteMealPushNotification(mealDate: treatment.timestamp, completion: completion)
                    }
                }))

                alert.addAction(UIAlertAction(title: "Endast Nightscout", style: .destructive, handler: { _ in
                    guard let treatmentId = treatment.documentId else {
                        completionHandler(false)
                        return
                    }
                    completionHandler(true)
                    self.applyLocalTreatmentDeletion(treatment)
                    NightscoutUtils.executeDeleteRequest(treatmentId: treatmentId) { result in
                        switch result {
                        case .success(_):
                            break
                        case .failure(let error):
                            DispatchQueue.main.async {
                                self.restoreLocalTreatment(treatment)
                                let failureAlert = UIAlertController(
                                    title: "Kunde inte radera!",
                                    message: "Kontrollera att du har skrivåtkomst i din Nightscout token",
                                    preferredStyle: .alert)
                                failureAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                                self.present(failureAlert, animated: true, completion: nil)
                            }
                            LogManager.shared.log(category: .treatments, message: "Failed to delete treatment: \(error.localizedDescription)", isDebug: true)
                        }
                    }
                }))

                alert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: { _ in
                    completionHandler(false)
                }))
                self.present(alert, animated: true, completion: nil)
            } else {
                // Use a custom display name for deletion alerts.
                let displayEventName: String
                if treatment.eventType == "Carb Correction" {
                    if let foodType = treatment.rawData["foodType"] as? String, !foodType.isEmpty {
                        displayEventName = "Kolhydrater"
                    } else {
                        displayEventName = "Fett & Protein"
                    }
                } else if treatment.eventType == "Note" {
                    displayEventName = "Notering"
                } else if treatment.eventType == "Exercise" {
                    displayEventName = "Override"
                } else if treatment.eventType == "Site Change" {
                    displayEventName = "Poddbyte"
                } else {
                    displayEventName = treatment.eventType
                }
                
                let message = "\nVill du verkligen radera:\n \(displayEventName) • \(timeString)?\n\n(OBS! Detta raderar INTE något i Trio)"
                let alert = UIAlertController(title: "Radera i Nightscout?", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: { _ in
                    completionHandler(false)
                }))
                alert.addAction(UIAlertAction(title: "Radera", style: .destructive, handler: { _ in
                    guard let treatmentId = treatment.documentId else {
                        completionHandler(false)
                        return
                    }
                    completionHandler(true)
                    self.applyLocalTreatmentDeletion(treatment)
                    NightscoutUtils.executeDeleteRequest(treatmentId: treatmentId) { result in
                        switch result {
                        case .success(_):
                            break
                        case .failure(let error):
                            DispatchQueue.main.async {
                                self.restoreLocalTreatment(treatment)
                                let failureAlert = UIAlertController(
                                    title: "Kunde inte radera!",
                                    message: "\nKontrollera att du har skrivåtkomst i din Nightscout token",
                                    preferredStyle: .alert)
                                failureAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                                self.present(failureAlert, animated: true, completion: nil)
                            }
                        }
                    }
                }))
                self.present(alert, animated: true, completion: nil)
            }
        }
        
        // Edit actions for updating duration on Exercise (Override) treatments
        // and editing note text for Note treatments.
        var actions: [UIContextualAction] = [deleteAction]

        if treatment.eventType == "Exercise" {
            let editAction = UIContextualAction(style: .normal, title: nil) { (action, view, completionHandler) in
                // Current duration in minutes (integer)
                let currentDuration = Int(treatment.overrideDuration ?? 0)

                let alert = UIAlertController(
                    title: "Ändra override-varaktighet i Nightscout",
                    message: "\nAnge ny längd i minuter\n\n(OBS! Detta ändrar INTE något i Trio)",
                    preferredStyle: .alert
                )

                alert.addTextField { textField in
                    textField.keyboardType = .numberPad
                    if currentDuration > 0 {
                        textField.text = String(currentDuration)
                    }
                }

                alert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: { _ in
                    completionHandler(false)
                }))

                alert.addAction(UIAlertAction(title: "Spara ändring", style: .default, handler: { _ in
                    guard let text = alert.textFields?.first?.text,
                          let newDurationInt = Int(text),
                          newDurationInt > 0 else {
                        completionHandler(false)
                        return
                    }

                    guard let treatmentId = treatment.documentId else {
                        self.showAlert(title: "Fel", message: "Saknar dokument-ID för behandlingen") { }
                        completionHandler(false)
                        return
                    }

                    // 1) Hämta aktuellt Nightscout-dokument
                    NightscoutUtils.fetchTreatmentById(treatmentId) { result in
                        switch result {
                        case .failure(let error):
                            self.showAlert(title: "Fel", message: error.localizedDescription) { }
                            completionHandler(false)
                        case .success(var doc):
                            // Ta bort _id så att Nightscout/MongoDB själv får skapa ett nytt ObjectId
                            doc.removeValue(forKey: "_id")

                            // Uppdatera duration i dokumentet
                            doc["duration"] = newDurationInt

                            // 2) Radera befintlig post
                            NightscoutUtils.executeDeleteRequest(treatmentId: treatmentId) { deleteResult in
                                switch deleteResult {
                                case .failure(let error):
                                    self.showAlert(title: "Kunde inte radera", message: error.localizedDescription) { }
                                    completionHandler(false)
                                case .success(_):
                                    // 3) Posta om samma treatment med uppdaterad duration (utan _id)
                                    Task {
                                        do {
                                            // Försök posta om overriden och få tillbaka det skapade dokumentet (med nytt _id).
                                            let createdDoc = try await NightscoutUtils.executePostRequestRaw(eventType: .treatments, body: doc)

                                            DispatchQueue.main.async {
                                                // Ta bort den gamla raden lokalt; den nya raden kommer ha ett nytt _id
                                                if let index = self.treatments.firstIndex(where: { $0.documentId == treatment.documentId }) {
                                                    let removed = self.treatments.remove(at: index)
                                                    self.removeTreatmentFromCache(removed)

                                                    // Om Nightscout svarade med det nya dokumentet, lägg in det direkt i listan
                                                    // och uppdatera cache-filen för rätt dag.
                                                    if let createdDoc = createdDoc,
                                                       let newTreatment = Treatment(dictionary: createdDoc as [String : AnyObject]) {
                                                        self.treatments.insert(newTreatment, at: index)
                                                        NightscoutCache.upsertTreatment(from: createdDoc)
                                                    }
                                                } else {
                                                    // Hittade inte den gamla raden, försök ändå lägga in den nya överst.
                                                    if let createdDoc = createdDoc,
                                                       let newTreatment = Treatment(dictionary: createdDoc as [String : AnyObject]) {
                                                        self.treatments.insert(newTreatment, at: 0)
                                                        NightscoutCache.upsertTreatment(from: createdDoc)
                                                    }
                                                }

                                                self.tableView.reloadData()
                                                self.updateDuplicateIndicator()
                                                completionHandler(true)
                                            }
                                        } catch {
                                            // Om uppladdningen misslyckas, lägg dokumentet i pending-kön för retry
                                            NightscoutUtils.addPendingUploadDocument(doc)

                                            DispatchQueue.main.async {
                                                self.showAlert(
                                                    title: "Kunde inte spara",
                                                    message: "\nOverride kunde inte laddas upp just nu. Den kommer att laddas upp automatiskt nästa gång Behandlingslogg öppnas."
                                                ) { }
                                                completionHandler(false)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }))

                self.present(alert, animated: true, completion: nil)
            }

            editAction.image = UIImage(systemName: "pencil")
            editAction.backgroundColor = .systemBlue

            actions = [deleteAction, editAction]
            
        } else if treatment.eventType == "Note" {
            let editNoteAction = UIContextualAction(style: .normal, title: nil) { (_, _, completionHandler) in
                self.presentEditNoteViewController(for: treatment, completionHandler: completionHandler)
            }

            editNoteAction.image = UIImage(systemName: "pencil")
            editNoteAction.backgroundColor = .systemBlue

            actions = [deleteAction, editNoteAction]

        /*} else if treatment.eventType == "Note" {
            let editNoteAction = UIContextualAction(style: .normal, title: nil) { (action, view, completionHandler) in
                // Current notes text
                let currentNotes = (treatment.rawData["notes"] as? String) ?? ""

                let alert = UIAlertController(
                    title: "Ändra noteringstext i Nightscout",
                    message: "\nRedigera texten nedan\n\n(OBS! Detta ändrar INTE något i Trio)",
                    preferredStyle: .alert
                )

                alert.addTextField { textField in
                    textField.keyboardType = .default
                    textField.autocapitalizationType = .sentences
                    textField.text = currentNotes
                }

                alert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: { _ in
                    completionHandler(false)
                }))

                alert.addAction(UIAlertAction(title: "Spara ändring", style: .default, handler: { _ in
                    guard let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !text.isEmpty else {
                        completionHandler(false)
                        return
                    }

                    guard let treatmentId = treatment.documentId else {
                        self.showAlert(title: "Fel", message: "Saknar dokument-ID för behandlingen") { }
                        completionHandler(false)
                        return
                    }

                    // 1) Hämta aktuellt Nightscout-dokument
                    NightscoutUtils.fetchTreatmentById(treatmentId) { result in
                        switch result {
                        case .failure(let error):
                            self.showAlert(title: "Fel", message: error.localizedDescription) { }
                            completionHandler(false)
                        case .success(var doc):
                            // Ta bort _id så att Nightscout/MongoDB själv får skapa ett nytt ObjectId
                            doc.removeValue(forKey: "_id")

                            // Uppdatera notes i dokumentet
                            doc["notes"] = text

                            // 2) Radera befintlig post
                            NightscoutUtils.executeDeleteRequest(treatmentId: treatmentId) { deleteResult in
                                switch deleteResult {
                                case .failure(let error):
                                    self.showAlert(title: "Kunde inte radera", message: error.localizedDescription) { }
                                    completionHandler(false)
                                case .success(_):
                                    // 3) Posta om samma treatment med uppdaterad notes (utan _id)
                                    Task {
                                        do {
                                            let createdDoc = try await NightscoutUtils.executePostRequestRaw(eventType: .treatments, body: doc)

                                            DispatchQueue.main.async {
                                                // Ta bort den gamla raden lokalt
                                                if let index = self.treatments.firstIndex(where: { $0.documentId == treatment.documentId }) {
                                                    let removed = self.treatments.remove(at: index)
                                                    self.removeTreatmentFromCache(removed)

                                                // Lägg in den nya raden direkt om vi fick tillbaka dokumentet
                                                // och uppdatera cache-filen för rätt dag.
                                                if let createdDoc = createdDoc,
                                                   let newTreatment = Treatment(dictionary: createdDoc as [String : AnyObject]) {
                                                    self.treatments.insert(newTreatment, at: index)
                                                    NightscoutCache.upsertTreatment(from: createdDoc)
                                                }
                                                } else {
                                                // Om vi inte hittade den, lägg den nya överst som fallback
                                                if let createdDoc = createdDoc,
                                                   let newTreatment = Treatment(dictionary: createdDoc as [String : AnyObject]) {
                                                    self.treatments.insert(newTreatment, at: 0)
                                                    NightscoutCache.upsertTreatment(from: createdDoc)
                                                }
                                                }

                                                self.tableView.reloadData()
                                                self.updateDuplicateIndicator()
                                                completionHandler(true)
                                            }
                                        } catch {
                                            // Om uppladdningen misslyckas, lägg dokumentet i pending-kön för retry
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
                }))

                self.present(alert, animated: true, completion: nil)
            }

            editNoteAction.image = UIImage(systemName: "pencil")
            editNoteAction.backgroundColor = .systemBlue

            actions = [deleteAction, editNoteAction]*/

        }

        // Set the trashcan SF Symbol and customize appearance.
        deleteAction.image = UIImage(systemName: "trash")
        deleteAction.backgroundColor = .red

        let configuration = UISwipeActionsConfiguration(actions: actions)
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
}
