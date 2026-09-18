import UIKit
import LocalAuthentication
import AudioToolbox

extension TreatmentsTableView {
    // MARK: - Remote Delete for Carb Correction (Trio)
        func deleteEntryInTrio(for treatment: Treatment) {
            // Extract carbohydrates from treatment's rawData.
            let carbsValue: Double
            if let carbsStr = treatment.rawData["carbs"] as? String, let value = Double(carbsStr) {
                carbsValue = value
            } else if let carbsNum = treatment.rawData["carbs"] as? Double {
                carbsValue = carbsNum
            } else {
                carbsValue = 0
            }
            
            // Format the treatment's timestamp.
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "sv_SE")
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let formattedDate = dateFormatter.string(from: treatment.timestamp)
            
            // Retrieve additional details from user defaults.
            let name = UserDefaultsRepository.caregiverName.value
            let secret = UserDefaultsRepository.remoteSecretCode.value
            
            // Get current timestamp.
            let currentTimestamp = Date()
            let formattedTimestamp = dateFormatter.string(from: currentTimestamp)
            
            // Build the combined command string.
            let combinedString = "Remote Delete\nKolhydrater: \(carbsValue)g\nDatum: \(formattedDate)\nInlagt av: \(name)\nSecret: \(secret)\nSkickades: \(formattedTimestamp)"
            
            // Send the remote command.
            sendRemoteDeleteCommand(combinedString: combinedString, treatment: treatment)
        }

    private func sendRemoteDeleteCommand(combinedString: String, treatment: Treatment) {
        // Retrieve the method from user defaults.
        let method = UserDefaultsRepository.method.value
        
        if method != "SMS API" {
            // Use the Shortcuts URL scheme.
            guard let encodedString = combinedString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                LogManager.shared.log(category: .treatments, message: "Failed to encode URL string", isDebug: true)
                return
            }
            // Define callback URLs.
            let successCallback = "loop://completed"
            let errorCallback = "loop://error"
            let cancelCallback = "loop://cancel"
            
            guard let successEncoded = successCallback.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let errorEncoded = errorCallback.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let cancelEncoded = cancelCallback.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                LogManager.shared.log(category: .treatments, message: "Failed to encode callback URLs", isDebug: true)
                return
            }
            
            let urlString = "shortcuts://x-callback-url/run-shortcut?name=Remote%20Delete&input=text&text=\(encodedString)&x-success=\(successEncoded)&x-error=\(errorEncoded)&x-cancel=\(cancelEncoded)"
            if let url = URL(string: urlString) {
                pendingShortcutDeletion = treatment
                applyLocalTreatmentDeletion(treatment)
                UIApplication.shared.open(url, options: [:]) { opened in
                    if !opened {
                        DispatchQueue.main.async {
                            self.finishShortcutDeletion(success: false)
                        }
                    }
                }
            }
            LogManager.shared.log(category: .treatments, message: "Waiting for shortcut completion...", isDebug: true)
        } else {
            // For SMS API, first show a confirmation alert with authentication.
            showRemoteDeleteConfirmationAlert(combinedString: combinedString, treatment: treatment)
        }
    }

    /// Presents a confirmation alert for SMS deletion. If the user selects "Ja", we authenticate first.
    private func showRemoteDeleteConfirmationAlert(combinedString: String, treatment: Treatment) {
        let confirmationAlert = UIAlertController(
            title: "Bekräfta radering",
            message: "\nÄr du säker på att du vill radera måltiden i Trio?",
            preferredStyle: .alert)
        
        confirmationAlert.addAction(UIAlertAction(title: "Radera", style: .destructive, handler: { _ in
            // Authenticate with biometrics; on success, send the command.
            self.authenticateWithBiometrics {
                self.sendRemoteDeleteCommandInternal(combinedString: combinedString, treatment: treatment)
            }
        }))
        
        confirmationAlert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: { _ in
            self.handleAlertDismissal()
        }))
        
        self.present(confirmationAlert, animated: true, completion: nil)
    }

    /// Actually sends the remote delete command via Twilio (SMS API).
    private func sendRemoteDeleteCommandInternal(combinedString: String, treatment: Treatment) {
        applyLocalTreatmentDeletion(treatment)
        twilioRequest(combinedString: combinedString) { result in
            switch result {
            case .success:
                AudioServicesPlaySystemSound(SystemSoundID(1322))
                DispatchQueue.main.async {
                    self.showAlert(title: "Lyckades!", message: "\nMeddelandet levererades") { }
                }
            case .failure(let error):
                AudioServicesPlaySystemSound(SystemSoundID(1053))
                DispatchQueue.main.async {
                    self.restoreLocalTreatment(treatment)
                    self.showAlert(title: "Fel", message: error.localizedDescription) { }
                }
            }
        }
    }

    /// MARK: - Authentication & Alert Helpers

    func authenticateWithBiometrics(completion: @escaping () -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate with biometrics to proceed"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        completion()
                    } else {
                        if let error = authenticationError as NSError?,
                           error.code == LAError.biometryNotAvailable.rawValue ||
                           error.code == LAError.biometryNotEnrolled.rawValue {
                            self.authenticateWithPasscode(completion: completion)
                        } else {
                            LogManager.shared.log(category: .treatments, message: "Authentication failed: \(authenticationError?.localizedDescription ?? "unknown error")", isDebug: true)
                            self.handleAlertDismissal()
                        }
                    }
                }
            }
        } else {
            self.authenticateWithPasscode(completion: completion)
        }
    }

    func authenticateWithPasscode(completion: @escaping () -> Void) {
        let context = LAContext()
        
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Authenticate with passcode to proceed") { success, error in
            DispatchQueue.main.async {
                if success {
                    completion()
                } else {
                    LogManager.shared.log(category: .treatments, message: "Authentication failed: \(error?.localizedDescription ?? "unknown error")", isDebug: true)
                    self.handleAlertDismissal()
                }
            }
        }
    }


    // MARK: - Shortcut Callback Handlers (without dismissing the view)

    private func finishShortcutDeletion(success: Bool) {
        guard let treatment = pendingShortcutDeletion else { return }
        pendingShortcutDeletion = nil
        if !success {
            restoreLocalTreatment(treatment)
        }
    }

    @objc func handleShortcutSuccess() {
        finishShortcutDeletion(success: true)
        LogManager.shared.log(category: .treatments, message: "Shortcut succeeded", isDebug: true)
        AudioServicesPlaySystemSound(SystemSoundID(1322))
        showAlert(title: NSLocalizedString("Lyckades", comment: "Lyckades"),
                  message: NSLocalizedString("\nMeddelandet levererades", comment: "Meddelandet levererades"),
                  completion: { /* No dismissal here */ })
    }

    @objc func handleShortcutError() {
        finishShortcutDeletion(success: false)
        LogManager.shared.log(category: .treatments, message: "Shortcut failed, showing error alert...", isDebug: true)
        AudioServicesPlaySystemSound(SystemSoundID(1053))
        showAlert(title: NSLocalizedString("Misslyckades", comment: "Misslyckades"),
                  message: NSLocalizedString("\nEtt fel uppstod när genvägen skulle köras. Du kan försöka igen.", comment: "Ett fel uppstod när genvägen skulle köras. Du kan försöka igen."),
                  completion: { /* Re-enable send button if needed */ })
    }

    @objc func handleShortcutCancel() {
        finishShortcutDeletion(success: false)
        LogManager.shared.log(category: .treatments, message: "Shortcut was cancelled, showing cancellation alert...", isDebug: true)
        AudioServicesPlaySystemSound(SystemSoundID(1053))
        showAlert(title: NSLocalizedString("Avbröts", comment: "Avbröts"),
                  message: NSLocalizedString("\nGenvägen avbröts innan den körts färdigt. Du kan försöka igen.", comment: "Genvägen avbröts innan den körts färdigt. Du kan försöka igen."),
                  completion: { /* Re-enable send button if needed */ })
    }

    @objc func handleShortcutPasscode() {
        finishShortcutDeletion(success: false)
        LogManager.shared.log(category: .treatments, message: "Shortcut was cancelled due to wrong passcode, showing passcode alert...", isDebug: true)
        AudioServicesPlaySystemSound(SystemSoundID(1053))
        showAlert(title: NSLocalizedString("Fel lösenkod", comment: "Fel lösenkod"),
                  message: NSLocalizedString("\nGenvägen avbröts pga fel lösenkod. Du kan försöka igen.", comment: "Genvägen avbröts pga fel lösenkod. Du kan försöka igen."),
                  completion: { /* Re-enable send button if needed */ })
    }
    
    /// Presents an alert with a title, message, and calls completion after dismissal.
}
