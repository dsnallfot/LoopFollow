import HealthKit
import SwiftUI
import UIKit

@available(iOS 16.0, *)
extension AddUserDataView {
    // MARK: - Helpers for auto-populating actual fields

    func clearActualFields() {
        actualBasalText = ""
        actualMorningCRText = ""
        actualDayCRText = ""
        actualAverageISFText = ""
    }

    private func hourlyCR(from schedule: [ProfileManager.TimeValue<Double>]) -> [Int: Double] {
        var dict: [Int: Double] = [:]
        var last: Double?
        var scheduleByHour: [Int: Double] = [:]

        for entry in schedule {
            scheduleByHour[entry.timeAsSeconds / 3600] = entry.value
        }

        for hour in 0..<24 {
            if let new = scheduleByHour[hour] {
                last = new
            }
            if let last {
                dict[hour] = last
            }
        }
        return dict
    }

    private func hourlyISF(from schedule: [ProfileManager.TimeValue<HKQuantity>], unit: HKUnit) -> [Int: Double] {
        var dict: [Int: Double] = [:]
        var last: Double?
        var scheduleByHour: [Int: Double] = [:]

        for entry in schedule {
            scheduleByHour[entry.timeAsSeconds / 3600] = entry.value.doubleValue(for: unit)
        }

        for hour in 0..<24 {
            if let new = scheduleByHour[hour] {
                last = new
            }
            if let last {
                dict[hour] = last
            }
        }
        return dict
    }

    func value(nearHour targetHour: Int, in dict: [Int: Double]) -> Double? {
        guard !dict.isEmpty else { return nil }
        guard let bestHour = dict.keys.min(by: { abs($0 - targetHour) < abs($1 - targetHour) }) else {
            return nil
        }
        return dict[bestHour]
    }

    func populateActualFieldsFromCurrentProfile() {
        let calendar = Calendar.current
        guard calendar.isDateInToday(updatedDate) else { return }

        // Försök auto-populera TDD (14-dagars medelvärde) beräknad av SimpleStatsViewModel.
            if tddText.isEmpty {
                let storedTDD = UserDefaults.standard.double(forKey: "Stats14DayAverageTDD")
                if storedTDD > 0 {
                    tddText = String(format: "%.1f", storedTDD)
                }
            }
        
        let profile = ProfileManager.shared

        // actualBasal: total daglig basal från basalschemat
        if actualBasalText.isEmpty {
            var lastBasal: Double?
            var basalDict: [Int: Double] = [:]
            for entry in profile.basalSchedule {
                basalDict[entry.timeAsSeconds / 3600] = entry.value
            }

            var totalDailyBasal: Double = 0
            for hour in 0..<24 {
                if let newBasal = basalDict[hour] {
                    lastBasal = newBasal
                }
                if let basal = lastBasal {
                    totalDailyBasal += basal
                }
            }

            if totalDailyBasal > 0 {
                actualBasalText = String(format: "%.2f", totalDailyBasal)
            }
        }

        // actualMorningCR & actualDayCR från CR-schema (timme 08 och 18, närmaste)
        let crByHour = hourlyCR(from: profile.carbRatioSchedule)

        if actualMorningCRText.isEmpty, let morningCR = value(nearHour: 8, in: crByHour) {
            actualMorningCRText = String(format: "%.1f", morningCR)
        }

        if actualDayCRText.isEmpty, let dayCR = value(nearHour: 18, in: crByHour) {
            actualDayCRText = String(format: "%.1f", dayCR)
        }

        // actualAverageISF = medelvärde av ISF över dygnet
        let isfByHour = hourlyISF(from: profile.isfSchedule, unit: profile.units)
        if actualAverageISFText.isEmpty {
            let values = Array(isfByHour.values)
            if !values.isEmpty {
                let sum = values.reduce(0, +)
                let avg = sum / Double(values.count)
                actualAverageISFText = String(format: "%.1f", avg)
            }
        }
    }
}
