import Foundation
import HealthKit

extension ProfileSchedulesViewModel {
    func calculateBasalSchedule(basalSchedule: [ProfileManager.TimeValue<Double>]) -> [ScheduleEntry] {
            var basalEntries: [ScheduleEntry] = []
            var lastBasal: Double?
            var basalDict: [Int: Double] = [:]
            var totalDailyBasal: Double = 0

            // Store basal values in a lookup dictionary
            for entry in basalSchedule {
                basalDict[entry.timeAsSeconds / 3600] = entry.value
            }

            // Generate a complete 24-hour schedule
            for hour in 0..<24 {
                if let newBasal = basalDict[hour] {
                    lastBasal = newBasal
                }

                if let basal = lastBasal {
                    totalDailyBasal += basal
                    let time = String(format: "%02d:00", hour)
                    basalEntries.append(ScheduleEntry(time: time, value: String(format: "%.2f", basal)))
                }
            }

            // Append total daily basal row
            basalEntries.append(ScheduleEntry(time: "Total daglig basal", value: String(format: "%.2f", totalDailyBasal)))

            return basalEntries
        }
    
    func calculateCSFSchedule(isfSchedule: [ProfileManager.TimeValue<HKQuantity>],
                                      carbRatioSchedule: [ProfileManager.TimeValue<Double>],
                                      unit: HKUnit) -> [ScheduleEntry] {
        var csfEntries: [ScheduleEntry] = []
        var lastISF: Double?
        var lastCarbRatio: Double?
        var isfDict: [Int: Double] = [:]
        var carbRatioDict: [Int: Double] = [:]
        
        // Convert ISF schedule to a lookup dictionary
        for entry in isfSchedule {
            isfDict[entry.timeAsSeconds / 3600] = entry.value.doubleValue(for: unit)
        }
        
        // Convert Carb Ratio schedule to a lookup dictionary
        for entry in carbRatioSchedule {
            carbRatioDict[entry.timeAsSeconds / 3600] = entry.value
        }
        
        // Compute CSF for every full hour
        for hour in 0..<24 {
            if let newISF = isfDict[hour] {
                lastISF = newISF
            }
            if let newCarbRatio = carbRatioDict[hour] {
                lastCarbRatio = newCarbRatio
            }

            if let isf = lastISF, let carbRatio = lastCarbRatio, carbRatio != 0 {
                let csf = isf / carbRatio
                let time = String(format: "%02d:00", hour)
                csfEntries.append(ScheduleEntry(time: time, value: String(format: "%.2f", csf)))
            }
        }

        return csfEntries
    }

    func calculateMinCarbsSchedule(isfSchedule: [ProfileManager.TimeValue<HKQuantity>],
                                               carbRatioSchedule: [ProfileManager.TimeValue<Double>],
                                               unit: HKUnit) -> [ScheduleEntry] {
            var minCarbsEntries: [ScheduleEntry] = []
            var lastISF: Double?
            var lastCarbRatio: Double?
            var isfDict: [Int: Double] = [:]
            var carbRatioDict: [Int: Double] = [:]
            var totalMinCarbs: Double = 0

            for entry in isfSchedule {
                isfDict[entry.timeAsSeconds / 3600] = entry.value.doubleValue(for: unit)
            }

            for entry in carbRatioSchedule {
                carbRatioDict[entry.timeAsSeconds / 3600] = entry.value
            }

            for hour in 0..<24 {
                if let newISF = isfDict[hour] {
                    lastISF = newISF
                }
                if let newCarbRatio = carbRatioDict[hour] {
                    lastCarbRatio = newCarbRatio
                }

                if let isf = lastISF, let carbRatio = lastCarbRatio, isf != 0 {
                    let minCarbs = (self.minCarbImpact * (carbRatio / (isf * 18.181818))) * 12
                    totalMinCarbs += minCarbs
                    let time = String(format: "%02d:00", hour)
                    minCarbsEntries.append(ScheduleEntry(time: time, value: String(format: "%.0f", minCarbs)))
                }
            }

            let averageMinCarbs = totalMinCarbs / 24
            minCarbsEntries.append(ScheduleEntry(time: "Medelvärde", value: String(format: "%.0f", averageMinCarbs)))

            return minCarbsEntries
        }
    
    func calculateSMBSchedule(basalSchedule: [ProfileManager.TimeValue<Double>],
                                      maxSMBMinutes: Int,
                                      maxUAMSMBMinutes: Int) -> [ScheduleEntry] {
        var entries: [ScheduleEntry] = []
        var lastBasal: Double?
        var basalDict: [Int: Double] = [:]

        for entry in basalSchedule {
            basalDict[entry.timeAsSeconds / 3600] = entry.value
        }

        for hour in 0..<24 {
            if let newBasal = basalDict[hour] {
                lastBasal = newBasal
            }

            if let basal = lastBasal {
                let maxSMB = basal * Double(maxSMBMinutes) / 60.0
                let maxUAMSMB = basal * Double(maxUAMSMBMinutes) / 60.0
                let time = String(format: "%02d:00", hour)
                let roundedSMB = (maxSMB * 100).rounded() / 100
                let roundedUAMSMB = (maxUAMSMB * 100).rounded() / 100
                let value = String(format: "%.2f / %.2f", roundedSMB, roundedUAMSMB)
                entries.append(ScheduleEntry(time: time, value: value))
            }
        }

        return entries
    }
}
