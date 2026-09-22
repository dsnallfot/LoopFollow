import UIKit
import Charts

extension GlucoseStatsViewController {
    // MARK: - Data loading

    func loadDataAndApplyInitialPeriod() {
        Task {
            let cal = Calendar.current
            let now = Date()

            // Up to 90 days (align with cache retention if smaller)
            let daysBack = min(NightscoutCache.retentionDays, 91)

            guard let startDay = cal.date(byAdding: .day, value: -(daysBack - 1), to: cal.startOfDay(for: now)) else {
                await MainActor.run {
                    self.applyPeriod(self.selectedPeriod)
                }
                return
            }

            // Build all days list (oldest → newest)
            var days: [Date] = []
            days.reserveCapacity(daysBack)
            for offset in 0..<daysBack {
                if let d = cal.date(byAdding: .day, value: offset, to: startDay) {
                    days.append(cal.startOfDay(for: d))
                }
            }

            // Load datasets (and treatments for Sensorfel)
            let (allSGV, allTreatments) = await NightscoutCache.loadWindow(from: startDay, to: now)
            let nsOnlySGV = await GlucoseNSOnlyCache.loadWindow(from: startDay, to: now)
            self.allSGVJSON = allSGV

            // Build Sensorfel outages for the full window
            let outages = self.buildSensorErrorOutages(allSGV: allSGV, allTreatments: allTreatments, now: now)

            // Count unique readings per day using bucket dedupe
            let countsAllValuesByDay = self.countsByDayFromSGVJSON(allSGV, bucketSeconds: 240.0)
            let realtimeSGV = SGVJSON.includingUploadTimes(allSGV, from: nsOnlySGV)
            let countsNSOnlyByDay = self.countsByDayFromSGVJSON(realtimeSGV, bucketSeconds: 240.0, realtimeOnly: true)

            var countsAll: [Int] = []
            var countsNS: [Int] = []
            countsAll.reserveCapacity(days.count)
            countsNS.reserveCapacity(days.count)

            for day in days {
                countsAll.append(countsAllValuesByDay[day] ?? 0)
                countsNS.append(countsNSOnlyByDay[day] ?? 0)
            }

            // Unicorn counts per day
            let unicornsByDay = self.unicornCountsByDayFromSGVJSON(allSGV)

            await MainActor.run {
                self.allDays = days
                self.allCountsAllValues = countsAll
                self.allCountsNSOnly = countsNS
                self.allSensorErrorOutages = outages
                self.unicornsByDay = unicornsByDay

                // Apply initial period
                self.applyPeriod(self.selectedPeriod)
            }
        }
    }
}
