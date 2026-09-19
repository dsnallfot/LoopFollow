import Foundation

extension AlarmViewModel {
        // MARK: - High Alert Logic
        func getHighAlertRows() -> [AlarmRow] {
            var rows: [AlarmRow] = []
            let units = UserDefaultsRepository.units.value ?? "mg/dL"
            let isActive = UserDefaultsRepository.alertHighActive.value

            // 1. Active Switch
            rows.append(.toggle(title: "Aktiverat", isOn: isActive, id: "high_active"))
            guard isActive else { return rows }

            // 2. BG Level (Stepper)
            let bgValue = Double(UserDefaultsRepository.alertHighBG.value)
            rows.append(.valueStepper(
                title: "Glukos",
                value: bgValue,
                min: 120,
                max: 300,
                step: (units == "mmol/L" ? 0.1 : 1.0),
                unit: "",
                id: "high_bg"
            ))

            // 3. Persistent For (Minutes)
            rows.append(.valueStepper(
                title: "Varit hög i",
                value: Double(UserDefaultsRepository.alertHighPersistent.value),
                min: 0,
                max: 120,
                step: 1,
                unit: " min",
                id: "high_persistent"
            ))

            // 4. Default Snooze Time
            rows.append(.valueStepper(
                title: "Snooza",
                value: Double(UserDefaultsRepository.alertHighSnooze.value),
                min: 10,
                max: 120,
                step: 5,
                unit: " min",
                id: "high_snooze"
            ))

            // 5. Sound Selection
            rows.append(.soundPicker(
                title: "Larmljud",
                currentSound: UserDefaultsRepository.alertHighSound.value ?? "Default",
                id: "high_sound"
            ))

            // 6. Play Sound
            rows.append(.optionPicker(
                title: "Spela larm",
                currentOption: UserDefaultsRepository.alertHighAudible.value,
                options: ["Alltid", "Nattetid", "Dagtid", "Aldrig"],
                id: "high_audible"
            ))

            // 7. Repeat Sound
            rows.append(.optionPicker(
                title: "Repetera larm",
                currentOption: UserDefaultsRepository.alertHighRepeat.value,
                options: ["Aldrig", "Alltid", "Nattetid", "Dagtid"],
                id: "high_repeat"
            ))

            // 8. Pre-Snooze (AutoSnooze)
            rows.append(.optionPicker(
                title: "För-Snooza",
                currentOption: UserDefaultsRepository.alertHighAutosnooze.value,
                options: ["Aldrig", "Nattetid", "Dagtid"],
                id: "high_autosnooze"
            ))

            // 9. Snoozed Until (Date)
            let storedSnoozedTime = UserDefaultsRepository.alertHighSnoozedTime.value
            let isSnoozed = UserDefaultsRepository.alertHighIsSnoozed.value
            let snoozedTime = isSnoozed ? storedSnoozedTime : nil

            rows.append(.dateValue(title: "Snoozad till", date: snoozedTime, id: "high_snoozed_time"))

            if snoozedTime != nil {
                rows.append(.toggle(title: "Är snoozad", isOn: isSnoozed, id: "high_is_snoozed"))
            }

            return rows
        }

        // MARK: - Urgent High Alert Logic
        func getUrgentHighAlertRows() -> [AlarmRow] {
            var rows: [AlarmRow] = []
            let units = UserDefaultsRepository.units.value ?? "mg/dL"
            let isActive = UserDefaultsRepository.alertUrgentHighActive.value

            // 1. Active Switch
            rows.append(.toggle(title: "Aktiverat", isOn: isActive, id: "urgent_high_active"))
            guard isActive else { return rows }

            // 2. BG Level (Stepper)
            let bgValue = Double(UserDefaultsRepository.alertUrgentHighBG.value)
            rows.append(.valueStepper(
                title: "Glukos",
                value: bgValue,
                min: 120,
                max: 350,
                step: (units == "mmol/L" ? 0.1 : 1.0),
                unit: "",
                id: "urgent_high_bg"
            ))

            // 3. Default Snooze Time
            rows.append(.valueStepper(
                title: "Snooza",
                value: Double(UserDefaultsRepository.alertUrgentHighSnooze.value),
                min: 10,
                max: 120,
                step: 5,
                unit: " min",
                id: "urgent_high_snooze"
            ))

            // 4. Sound Selection
            rows.append(.soundPicker(
                title: "Larmljud",
                currentSound: UserDefaultsRepository.alertUrgentHighSound.value ?? "Default",
                id: "urgent_high_sound"
            ))

            // 5. Play Sound
            rows.append(.optionPicker(
                title: "Spela larm",
                currentOption: UserDefaultsRepository.alertUrgentHighAudible.value,
                options: ["Alltid", "Nattetid", "Dagtid", "Aldrig"],
                id: "urgent_high_audible"
            ))

            // 6. Repeat Sound
            rows.append(.optionPicker(
                title: "Repetera larm",
                currentOption: UserDefaultsRepository.alertUrgentHighRepeat.value,
                options: ["Aldrig", "Alltid", "Nattetid", "Dagtid"],
                id: "urgent_high_repeat"
            ))

            // 7. Pre-Snooze (AutoSnooze)
            rows.append(.optionPicker(
                title: "För-Snooza",
                currentOption: UserDefaultsRepository.alertUrgentHighAutosnooze.value,
                options: ["Aldrig", "Nattetid", "Dagtid"],
                id: "urgent_high_autosnooze"
            ))

            // 8. Snoozed Until (Date)
            let storedSnoozedTime = UserDefaultsRepository.alertUrgentHighSnoozedTime.value
            let isSnoozed = UserDefaultsRepository.alertUrgentHighIsSnoozed.value
            let snoozedTime = isSnoozed ? storedSnoozedTime : nil

            rows.append(.dateValue(title: "Snoozad till", date: snoozedTime, id: "urgent_high_snoozed_time"))

            if snoozedTime != nil {
                rows.append(.toggle(title: "Är snoozad", isOn: isSnoozed, id: "urgent_high_is_snoozed"))
            }

            return rows
        }

}
