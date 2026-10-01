//
//  SensorStart.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-10-04.

//

import Foundation
extension MainViewController {
    func processSage(entries: [sageData]) {
        if !entries.isEmpty {
            updateSage(data: entries)
        } else if let sage = currentSage {
            updateSage(data: [sage])
        } else {
            webLoadNSSage()
        }
    }
    
    // NS Sensor Start Response Processor
    func processSensorStart(entries: [sageData]) {
        sensorStartGraphData.removeAll()
        var lastFoundIndex = 0

        // Load existing sensor start history
        var sensorStartHistory = Storage.shared.sensorStartNotes
        let previousHistory = sensorStartHistory

        for entry in entries {
            let date = entry.created_at

            if let parsedDate = NightscoutUtils.parseDate(date) {
                let dateTimeStamp = parsedDate.timeIntervalSince1970
                let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
                lastFoundIndex = sgv.foundIndex

                let thisNote = entry.notes ?? ""

                if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                    let dot = DataStructs.sensorStartStruct(date: Double(dateTimeStamp), sgv: Int(18), note: thisNote)
                    sensorStartGraphData.append(dot)

                    let newEntry = SensorStartHistoryEntry(date: dateTimeStamp, note: thisNote, trioSentAt: TreatmentJSON.parseTrioSentAt(entry.trioSentAt))

                    // Prevent duplicates before saving
                    if let index = sensorStartHistory.firstIndex(where: { $0.date == newEntry.date }) {
                        if let sentAt = newEntry.trioSentAt, sensorStartHistory[index].trioSentAt != sentAt {
                            sensorStartHistory[index].trioSentAt = sentAt
                        }
                    } else {
                        sensorStartHistory.append(newEntry)
                    }
                }
            } else {
                LogManager.shared.log(category: .nightscout, message: "Failed to parse date for sensor start", isDebug: true)
            }
        }

        // Invalidate only summaries whose ownership window changed; retain older archived analyses.
        let now = Date()
        for i in sensorStartHistory.indices {
            let current = sensorStartHistory[i]
            if let previous = previousHistory.first(where: { $0.date == current.date }),
               previous.sensorUsageWindow(in: previousHistory, now: now) != current.sensorUsageWindow(in: sensorStartHistory, now: now) {
                sensorStartHistory[i].sensorErrors = nil
            }
        }

        // 🔹 Save back to persistent storage only if it's an array
        if !sensorStartHistory.isEmpty {
            Storage.shared.sensorStartNotes = sensorStartHistory
        }
        
        if UserDefaultsRepository.graphOtherTreatments.value {
            updateSensorStart()
        }
    }
}
