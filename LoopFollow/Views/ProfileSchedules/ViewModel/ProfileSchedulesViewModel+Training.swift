import Foundation

extension ProfileSchedulesViewModel {
    func reloadTrainingSessions() {
        loadTrainingSessions()
    }
    
    func loadTrainingSessions() {
        Task {
            let now = Date()
            let cal = Calendar.current
            let start = cal.date(byAdding: .day, value: -NightscoutCache.retentionDays, to: now)
                ?? now.addingTimeInterval(-91 * 24 * 60 * 60)

            let (_, treatments) = await NightscoutCache.loadWindow(from: start, to: now)

            let relevantTreatments = treatments
                .filter { treatment in
                    if treatment.eventType == "Note" {
                        let note = (treatment.notes ?? "").lowercased()
                        return note.contains("meta quest spel")
                            || note.contains("träning startades")
                            || note.contains("träning avslutades")
                    }
                    if treatment.eventType == "Exercise" {
                        let note = (treatment.notes ?? "").lowercased()
                        return note.contains("gympa") || note.contains("hög aktivitet")
                    }
                    return false
                }
                .sorted { $0.created_at < $1.created_at }

            var sessions: [TrainingSessionEntry] = []
            var currentMetaQuestStart: Date?
            var currentOtherTrainingStart: Date?

            for treatment in relevantTreatments {
                let note = (treatment.notes ?? "").lowercased()

                if treatment.eventType == "Note" {
                    if note.contains("meta quest spel startades") {
                        currentMetaQuestStart = treatment.created_at
                        continue
                    }

                    if note.contains("träning startades") {
                        currentOtherTrainingStart = treatment.created_at
                        continue
                    }

                    if note.contains("meta quest spel avslutades"), let startDate = currentMetaQuestStart {
                        if treatment.created_at >= startDate {
                            sessions.append(
                                TrainingSessionEntry(
                                    category: .metaQuest,
                                    startDate: startDate,
                                    endDate: treatment.created_at
                                )
                            )
                        }
                        currentMetaQuestStart = nil
                        continue
                    }

                    if note.contains("träning avslutades"), let startDate = currentOtherTrainingStart {
                        if treatment.created_at >= startDate {
                            sessions.append(
                                TrainingSessionEntry(
                                    category: .training,
                                    startDate: startDate,
                                    endDate: treatment.created_at
                                )
                            )
                        }
                        currentOtherTrainingStart = nil
                        continue
                    }

                    continue
                }

                if treatment.eventType == "Exercise" {
                    guard let duration = treatment.tempBasalDuration, duration > 0 else { continue }

                    let category: TrainingSessionEntry.Category?
                    if note.contains("gympa") {
                        category = .gympa
                    } else if note.contains("hög aktivitet") {
                        category = .highActivity
                    } else {
                        category = nil
                    }

                    guard let category else { continue }

                    let startDate = treatment.created_at
                    let endDate = startDate.addingTimeInterval(duration * 60)

                    sessions.append(
                        TrainingSessionEntry(
                            category: category,
                            startDate: startDate,
                            endDate: endDate
                        )
                    )
                }
            }

            if let startDate = currentMetaQuestStart {
                sessions.append(
                    TrainingSessionEntry(
                        category: .metaQuest,
                        startDate: startDate,
                        endDate: nil
                    )
                )
            }

            if let startDate = currentOtherTrainingStart {
                sessions.append(
                    TrainingSessionEntry(
                        category: .training,
                        startDate: startDate,
                        endDate: nil
                    )
                )
            }

            await MainActor.run {
                self.trainingSessions = sessions.sorted { $0.startDate > $1.startDate }
            }
        }
    }
}
