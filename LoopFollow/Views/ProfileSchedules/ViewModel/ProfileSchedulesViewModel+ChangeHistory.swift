import Foundation

extension ProfileSchedulesViewModel {
    private func normalize(_ s: String) -> String {
        return s
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    func scanCachedProfileNoteTreatments() {
        Task {
            let now = Date()
            let cal = Calendar.current
            let start = cal.date(byAdding: .day, value: -NightscoutCache.retentionDays, to: now)
                ?? now.addingTimeInterval(-91 * 24 * 60 * 60)

            let (_, treatments) = await NightscoutCache.loadWindow(from: start, to: now)

            var latest: [String: Date] = [:]

            // Behåll termerna som du vill att de ska vara “mänskliga”
            let rawTargets = ["Basalprofil", "CR-profil", "ISF-profil", "Mål-profil"]

            for t in treatments {
                guard t.eventType == "Note", let note = t.notes else { continue }
                guard note.contains("Justerad") || note.contains("ändrades") else { continue }

                let n = normalize(note) // tar bort _ - och mellanslag osv

                for raw in rawTargets {
                    let target = normalize(raw)               // <-- nyckeln här!
                    guard n.contains(target) else { continue }

                    if let existing = latest[target] {
                        if t.created_at > existing { latest[target] = t.created_at }
                    } else {
                        latest[target] = t.created_at
                    }
                }
            }

            // Swift 6-snapshot (candidates från cache-fönstret)
            let basalKey  = normalize("Basalprofil")
            let crKey     = normalize("CR-profil")
            let isfKey    = normalize("ISF-profil")
            let targetKey = normalize("Mål-profil")

            let basalCandidate  = latest[basalKey]
            let crCandidate     = latest[crKey]
            let isfCandidate    = latest[isfKey]
            let targetCandidate = latest[targetKey]

            await MainActor.run {
                // Persist: se till att vi inte tappar bort dessa datum när cachen åldras ut.
                for (normalizedKey, date) in latest {
                    self.lastChangedStore.registerChange(forKey: normalizedKey, at: date)
                }

                // Merge: om candidate är nil (pga 90-dagars fönstret), visa ändå persisterat värde.
                self.lastChangedBasalProfile  = self.lastChangedStore.mergedLatest(forKey: basalKey, candidate: basalCandidate)
                self.lastChangedCRProfile     = self.lastChangedStore.mergedLatest(forKey: crKey, candidate: crCandidate)
                self.lastChangedISFProfile    = self.lastChangedStore.mergedLatest(forKey: isfKey, candidate: isfCandidate)
                self.lastChangedTargetProfile = self.lastChangedStore.mergedLatest(forKey: targetKey, candidate: targetCandidate)
            }
        }
    }
}
