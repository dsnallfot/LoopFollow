import SwiftUI
import UIKit

@available(iOS 16.0, *)
extension AddUserDataView {
    func loadExistingProfile() {
        if let existing = existingEntry {
            name = existing.name
            if let d = existing.birthDate { birthDate = d }
            if let d = existing.t1dSince { t1dSinceDate = d }
            if let h = existing.heightCm { heightText = String(format: "%.1f", h) }
            if let w = existing.weightKg { weightText = String(format: "%.1f", w) }
            if let dose = existing.tdd { tddText = String(format: "%.1f", dose) }
            if let hba1c = existing.hbA1c { hbA1cText = String(format: "%.0f", hba1c) }
            if let actualMorningCR = existing.actualMorningCR { actualMorningCRText = String(format: "%.1f", actualMorningCR) }
            if let actualDayCR = existing.actualDayCR { actualDayCRText = String(format: "%.1f", actualDayCR) }
            if let actualBasal = existing.actualBasal { actualBasalText = String(format: "%.2f", actualBasal) }
            if let actualAverageISF = existing.actualAverageISF { actualAverageISFText = String(format: "%.1f", actualAverageISF) }
            updatedDate = existing.updatedAt
        } else if let latest = Storage.shared.userProfiles.max(by: { $0.updatedAt < $1.updatedAt }) {
            name = latest.name
            if let d = latest.birthDate { birthDate = d }
            if let d = latest.t1dSince { t1dSinceDate = d }
            //if let h = latest.heightCm { heightText = String(format: "%.0f", h) }
            //if let w = latest.weightKg { weightText = String(format: "%.1f", w) }
            //if let dose = latest.tdd { tddText = String(format: "%.1f", dose) }
            //if let hba1c = latest.hbA1c { hbA1cText = String(format: "%.0f", hba1c) }
            if let actualMorningCR = latest.actualMorningCR { actualMorningCRText = String(format: "%.1f", actualMorningCR) }
            if let actualDayCR = latest.actualDayCR { actualDayCRText = String(format: "%.1f", actualDayCR) }
            if let actualBasal = latest.actualBasal { actualBasalText = String(format: "%.2f", actualBasal) }
            if let actualAverageISF = latest.actualAverageISF { actualAverageISFText = String(format: "%.1f", actualAverageISF) }
            updatedDate = Date()//latest.updatedAt
        }

        // Om vi skapar en NY registrering (existingEntry == nil)
        // och updatedDate är idag -> auto-populera actual*-fält från aktuell profil
        // (men inte i read-only-läge)
        if existingEntry == nil && !isReadOnly {
            populateActualFieldsFromCurrentProfile()
        }
    }

    func saveProfile() {
        let entry = UserProfileEntry(
            name: name,
            birthDate: birthDate,
            t1dSince: t1dSinceDate,
            heightCm: heightCm,
            weightKg: weightKg,
            tdd: tdd,
            hbA1c: hbA1c,
            actualBasal: actualBasal,
            actualMorningCR: actualMorningCR,
            actualDayCR: actualDayCR,
            actualAverageISF: actualAverageISF,
            updatedAt: updatedDate,
            insulinPerKg: insulinPerKg,
            walsh500CR: walsh500CR,
            walsh300CR: walsh300CR,
            walshWeightCR: walshWeightCR,
            walsh100ISF: walsh100ISF,
            walshTDD: walshTDD,
            walshBasal: walshBasal,
            walshBasalPerHour: walshBasalPerHour,
            actualBasalPerHour: actualBasalPerHour
        )

        var profiles = Storage.shared.userProfiles
        if let existing = existingEntry,
           let idx = profiles.firstIndex(where: { $0.updatedAt == existing.updatedAt && $0.name == existing.name }) {
            profiles[idx] = entry
        } else {
            profiles.append(entry)
        }
        Storage.shared.userProfiles = profiles

        NotificationCenter.default.post(name: .userProfileUpdated, object: nil)
        dismiss()
    }
}
