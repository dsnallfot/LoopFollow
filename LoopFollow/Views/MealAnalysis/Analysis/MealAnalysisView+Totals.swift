import UIKit

extension MealAnalysisView {
    private func scheduledBasal(from start: Date, to end: Date) -> Double {
        let schedule = ProfileManager.shared.basalSchedule  // array of .timeAsSeconds + value
        guard !schedule.isEmpty else { return 0 }
        let calendar = Calendar.current
        var total = 0.0
        var current = start

        func basalRate(at date: Date) -> Double {
            let comps = calendar.dateComponents([.hour, .minute, .second], from: date)
            let secondsOfDay = comps.hour! * 3600 + comps.minute! * 60 + comps.second!
            // find last entry whose timeAsSeconds <= secondsOfDay
            var rate = schedule.last!.value
            for entry in schedule {
                if entry.timeAsSeconds <= secondsOfDay {
                    rate = entry.value
                } else {
                    break
                }
            }
            return rate
        }

        func nextChange(after date: Date) -> Date {
            let cal = Calendar.current
            // Build DateComponents (hour,minute,second) for all schedule breakpoints
            let breakpoints: [DateComponents] = schedule.map { entry in
                let h = entry.timeAsSeconds / 3600
                let m = (entry.timeAsSeconds % 3600) / 60
                let s = entry.timeAsSeconds % 60
                var dc = DateComponents()
                dc.hour = h
                dc.minute = m
                dc.second = s
                return dc
            }
            var candidate: Date? = nil
            for dc in breakpoints {
                // Find the next occurrence of this wall time strictly AFTER `date`.
                // Use `.nextTime` + `.last` to pick the later occurrence on fall‑back days.
                if let d = cal.nextDate(after: date,
                                         matching: dc,
                                         matchingPolicy: .nextTime,
                                         repeatedTimePolicy: .last,
                                         direction: .forward) {
                    if d > date { // strictly after
                        if candidate == nil || d < candidate! {
                            candidate = d
                        }
                    }
                }
            }
            // If nothing found (shouldn’t happen), move 1 second forward to guarantee progress
            return candidate ?? cal.date(byAdding: .second, value: 1, to: date)!
        }

        while current < end {
            // Defensive: if for any reason `current` isn’t strictly advancing, push it by 1 second
            // (should be redundant with the new nextChange(), but prevents hangs)
            let rate = basalRate(at: current)
            let next = min(end, nextChange(after: current))
            // Ensure strict monotonicity across DST fall‑back;
            // if next did not move forward, bump by 1 second
            if next <= current {
                let bumped = Calendar.current.date(byAdding: .second, value: 1, to: current)!
                if bumped < end {
                    // Recompute with the bumped time to keep accounting precise
                    let strictNext = min(end, nextChange(after: bumped))
                    if strictNext > current {
                        // proceed with strictNext
                        let hours = strictNext.timeIntervalSince(current) / 3600.0
                        total += rate * hours
                        current = strictNext
                        continue
                    }
                }
                // Fallback: break to avoid an infinite loop
                break
            }
            let hours = next.timeIntervalSince(current) / 3600.0
            total += rate * hours
            current = next
        }
        return max(total, 0)
    }

    // MARK: - Summation
    func updateTotals() {
        insulinTotal = 0; bolusTotal = 0; smbTotal = 0; basalTotal = 0; carbsTotal = 0; fpuTotal = 0; profileBasalTotal = 0
        for event in events where event.date >= startTime && event.date <= endTime {
            switch event.eventType {
            case "SMB":
                smbTotal   += event.amount
            case "Bolus":
                bolusTotal += event.amount
            case "Carb Correction":
                carbsTotal += event.amount
                if (event.foodType ?? "").isEmpty {
                        fpuTotal += event.amount
                    }
            default: break
            }
        }
        // ——— Delivered Temp‑Basal pulses (0.05 U) with rate‑dependent timing ———
        basalTotal = 0
        let tempBasals = events
            .filter { $0.eventType == "Temp Basal" && $0.date < endTime }
            .sorted { $0.date < $1.date }
        //#if DEBUG
        //        print("Totals ▸ TempBasal events in window:")
        //tempBasals.forEach {
        //    print("Totals ▸   event \($0.date)  rate \($0.amount) U/h")
        //}
        //#endif

        //#if DEBUG
        // Carry‑over aware pulse simulation
        //#endif
        
        var residual = 0.0                      // undelivered <0.05 U from previous segment
        for (idx, evt) in tempBasals.enumerated() {
            let segmentStart = max(evt.date, startTime)
            let segmentEnd: Date = {
                if idx + 1 < tempBasals.count {
                    return min(tempBasals[idx + 1].date, endTime)
                } else {
                    return endTime
                }
            }()
            guard segmentStart < segmentEnd else { continue }
            let rate = evt.amount                       // U/h
            guard rate > 0 else {                       // 0 U/h just closes previous segment
                if !carryOverUndeliveredBasals { residual = 0 }
                continue
            }

            let ratePerSec = rate / 3600.0
            var t = segmentStart
            var accum = carryOverUndeliveredBasals ? residual : 0.0

            //#if DEBUG
            //print("Totals ▸ TempBasal  rate=\(rate) U/h  segmentStart=\(segmentStart)  segmentEnd=\(segmentEnd)  residualIn=\(accum)")
            //#endif

            while true {
                let remaining = 0.05 - accum
                let dt = remaining / ratePerSec            // seconds to next pulse
                if t.addingTimeInterval(dt) > segmentEnd { // will not reach next pulse
                    accum += ratePerSec * segmentEnd.timeIntervalSince(t)
                    t = segmentEnd
                    break
                }
                t = t.addingTimeInterval(dt)               // pulse moment
                if t >= startTime {
                    basalTotal += 0.05
                    //#if DEBUG
                    //print("Totals ▸   counting pulse \(t)")
                    //#endif
                }
                accum = 0.0                                // reset after delivery
            }

            residual = carryOverUndeliveredBasals ? accum : 0.0
        }
        //#if DEBUG
        //print("Totals ▸ basalTotal delivered = \(basalTotal) U")
        //#endif
        // scheduled basal for the timeframe
        // Round scheduled basal down to nearest 0.05
        let rawBasal = scheduledBasal(from: startTime, to: endTime)
        profileBasalTotal = floor(rawBasal / 0.05) * 0.05
        // Net insulin for meal = delivered insulin - scheduled profile basal
        let netInsulin = (smbTotal + bolusTotal + basalTotal) - profileBasalTotal
        // Derived statistics
        let realCR = netInsulin > 0.04 ? carbsTotal / netInsulin : 0
        let manualBolusPct = netInsulin > 0.04 ? (bolusTotal / netInsulin) * 100 : 0
        let manualBolusPctString = String(format: "%.0f %%", manualBolusPct)
        let smbTempDelivered = smbTotal + basalTotal - profileBasalTotal
        let smbTempPct = netInsulin > 0.04 ? (smbTempDelivered / netInsulin) * 100 : 0
        let smbTempPctString = String(format: "%.0f %%", smbTempPct)
        // update UI
        insulinTotalValueLabel.text = String(format: "%.2f E", netInsulin)
        bolusValueLabel.text        = String(format: "+%.2f E", bolusTotal)
        smbValueLabel.text          = String(format: "+%.2f E", smbTotal)
        basalValueLabel.text        = String(format: "+%.2f E", basalTotal)
        profileBasalValueLabel.text = String(format: "-%.2f E", profileBasalTotal)
        carbsValueLabel.text        = String(format: "%.0f g",  carbsTotal)
        fpuValueLabel.text          = String(format: "%.0f g", fpuTotal)
        realCRValueLabel.text       = realCR > 0 ? String(format: "%.0f g/E", realCR) : "-- g/E"
        manualBolusValueLabel.text  = String(format: "%.0f %%", manualBolusPct)
        smbTempValueLabel.text      = String(format: "%.0f %%", smbTempPct)
        manualVsAutomatedLabel.text = realCR > 0 ? "\(manualBolusPctString) vs \(smbTempPctString)" : "-- % vs -- %"
        updateBGLabels()
    }
}
