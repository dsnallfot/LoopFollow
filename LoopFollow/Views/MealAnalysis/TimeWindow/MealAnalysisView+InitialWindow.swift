import UIKit

extension MealAnalysisView {
    func configureInitialWindow() {
        if modalWithTimestamp {
            //title = "Analys måltid"
            title = modalTitleString
        } else {
            title = "Analys tid"
        }

        let calendar = Calendar.current

        // When opened without a linked entry, default to "Dag" (today 00:00–now)
        if !modalWithTimestamp {
            durationControl.selectedSegmentIndex = 6   // "Dag"
            let now = Date()
            startTime = calendar.startOfDay(for: now)
            endTime = now
        }
        // When opened with an exact-midnight timestamp (00:00), treat it as a full-day report.
        else if let startOverride = initialStartOverride {
            let dayStart = calendar.startOfDay(for: startOverride)
            // "modalWithExactMidnight": start time is exactly at this day's 00:00
            let isExactMidnight = calendar.compare(startOverride, to: dayStart, toGranularity: .minute) == .orderedSame
            if let endOverride = initialEndOverride {
                durationControl.selectedSegmentIndex = preSelectedSegment ?? 8//UISegmentedControl.noSegment
                startTime = dayStart
                endTime = endOverride
            } else if isExactMidnight {
                durationControl.selectedSegmentIndex = 6   // "Dag"
                startTime = dayStart
                if calendar.isDateInToday(dayStart) {
                    // För idag: 00:00 → nu
                    endTime = Date()
                } else {
                    // För tidigare dagar: fulla 24h
                    durationControl.selectedSegmentIndex = 5   // "24h"
                    endTime = calendar.date(byAdding: .day, value: 1, to: dayStart)
                        ?? dayStart.addingTimeInterval(24 * 60 * 60)
                }
            }
        }
    }

    func configureTimePickers() {
        // Configure picker limits (now‒24h ... ∞) and initial value
        let minDate = Date().addingTimeInterval(TimeInterval(-24 * 60 * 60 * UserDefaultsRepository.downloadDays.value))
        let now = Date()

        endPicker.minimumDate = minDate
        endPicker.maximumDate = now
        endPicker.date = endTime
        endPicker.addTarget(self, action: #selector(endTimeChanged(_:)), for: .valueChanged)

        startPicker.minimumDate = minDate
        startPicker.maximumDate = now
        startPicker.date = startTime

        // Apply caller-provided start time override if provided
        if modalWithTimestamp, let startOverride = initialStartOverride {
            startTime = startOverride
            startPicker.date = startOverride
            // Här låter vi recalcEndTimeBasedOnDuration() längst ner ta hand om endTime,
            // så vi behöver inte kalla den en extra gång här.
        }
        startPicker.addTarget(self, action: #selector(startTimeChanged(_:)), for: .valueChanged)

        // Configure duration control action
        durationControl.addTarget(self, action: #selector(durationChanged(_:)), for: .valueChanged)
    }

    func normalizeInitialDuration() {
        // NEW: se till att lastDurationTitle alltid matchar det segment vi faktiskt står på
        let initialIndex = durationControl.selectedSegmentIndex
        if initialIndex != UISegmentedControl.noSegment,
           initialIndex < durationControl.numberOfSegments {
            lastDurationTitle = durationControl.titleForSegment(at: initialIndex)
            // NEW: första gången – låt recalcEndTimeBasedOnDuration normalisera fönstret
            recalcEndTimeBasedOnDuration()
        } else {
            // Ingen aktivt valt segment (t.ex. vid exakta override-intervall):
            // behåll startTime/endTime som de är och låt lastDurationTitle vara nil.
            lastDurationTitle = nil
        }
    }
}
