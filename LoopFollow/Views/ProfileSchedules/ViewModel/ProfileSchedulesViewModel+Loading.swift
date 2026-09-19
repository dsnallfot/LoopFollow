import Foundation
import HealthKit

extension ProfileSchedulesViewModel {
    func fetchProfileData() {
            // First fetch preferences to get min_5m_carbimpact value
            fetchPreferences { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    let profile = ProfileManager.shared
                    
                    // Fetch and format basal schedule
                    self.basalEntries = self.calculateBasalSchedule(basalSchedule: profile.basalSchedule)
                    
                    // Efter att du satt self.basalEntries
                    let basalIOBTimeValues = BasalIOBCalculator.computeBasalIOBTimeValues(
                        from: profile.basalSchedule
                    )

                    // Om du vill visa det i din ProfileSchedulesView:
                    var basalIOBEntries: [ScheduleEntry] = basalIOBTimeValues.map { entry in
                        ScheduleEntry(
                            time: self.formatTime(entry.timeAsSeconds),
                            value: String(format: "%.2f", entry.value)
                        )
                    }

                    // Lägg till medelvärde längst ned
                    let totalIOB = basalIOBTimeValues.reduce(0.0) { partial, entry in
                        partial + entry.value
                    }
                    let averageIOB = basalIOBTimeValues.isEmpty ? 0.0 : totalIOB / Double(basalIOBTimeValues.count)
                    basalIOBEntries.append(
                        ScheduleEntry(
                            time: "Medel basal IOB/h",
                            value: String(format: "%.2f", averageIOB)
                        )
                    )

                    self.basalIOBEntries = basalIOBEntries
                    
                    // Fetch and format carb ratio schedule
                    self.carbRatioEntries = profile.carbRatioSchedule.map { entry in
                        let value: String
                        if entry.value.truncatingRemainder(dividingBy: 1) == 0 {
                            value = "\(Int(entry.value))"
                        } else {
                            value = String(format: "%.1f", entry.value)
                        }

                        return ScheduleEntry(time: self.formatTime(entry.timeAsSeconds), value: value)
                    }

                    // Fetch and format ISF schedule
                    self.isfEntries = profile.isfSchedule.map { entry in
                        let value = entry.value.doubleValue(for: profile.units)
                        return ScheduleEntry(time: self.formatTime(entry.timeAsSeconds), value: String(format: "%.1f", value))
                    }

                    // Fetch and format Target schedule
                    self.targetEntries = profile.targetLowSchedule.map { entry in
                        let value = entry.value.doubleValue(for: profile.units)
                        return ScheduleEntry(time: self.formatTime(entry.timeAsSeconds), value: String(format: "%.1f", value))
                    }

                    // Compute CSF schedule
                    self.csfEntries = self.calculateCSFSchedule(isfSchedule: profile.isfSchedule, carbRatioSchedule: profile.carbRatioSchedule, unit: profile.units)

                    // Compute Minimum Carbs g/Hr schedule
                    self.minCarbsEntries = self.calculateMinCarbsSchedule(isfSchedule: profile.isfSchedule, carbRatioSchedule: profile.carbRatioSchedule, unit: profile.units)
                }
            }
        }
    
    private func fetchPreferences(completion: @escaping () -> Void) {
        NightscoutUtils.executeRequest(eventType: .profile, parameters: [:]) { (result: Result<NSProfile, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let profileData):
                    // Existing logic for minCarbImpact
                    if let value = profileData.nsPreferences?.preferences["min_5m_carbimpact"],
                       let impact = Double(value) {
                        self.minCarbImpact = impact
                    }

                    // ✅ New: Extract SMB preferences here
                    let maxSMBMinutes = Int(profileData.nsPreferences?.preferences["maxSMBBasalMinutes"] ?? "") ?? 30
                    let maxUAMSMBMinutes = Int(profileData.nsPreferences?.preferences["maxUAMSMBBasalMinutes"] ?? "") ?? 30

                    // ✅ Trigger SMB calculation
                    let profile = ProfileManager.shared
                    self.smbEntries = self.calculateSMBSchedule(
                        basalSchedule: profile.basalSchedule,
                        maxSMBMinutes: maxSMBMinutes,
                        maxUAMSMBMinutes: maxUAMSMBMinutes
                    )

                case .failure(let error):
                    LogManager.shared.log(category: .trio, message: "Error fetching preferences: \(error)", isDebug: true)
                }

                completion()
            }
        }
    }
    
        private func formatTime(_ seconds: Int) -> String {
            let hours = seconds / 3600
            return String(format: "%02d:00", hours)
        }
}
